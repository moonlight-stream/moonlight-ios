# 手柄模拟鼠标与键盘模式 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 Moonlight iOS/tvOS 添加手柄模拟鼠标模式和虚拟键盘覆盖层，让用户在没有鼠标键盘时也能用手柄操作桌面应用。

**Architecture:** 创建独立的 `GamepadMouseHandler` 类负责手柄-鼠标翻译，在 `ControllerSupport.updateFinished:` 中拦截手柄输入并分发。虚拟键盘使用自定义 `KeyboardOverlayView` 覆盖层，通过 tvOS Focus Engine 导航。平台参数通过 `GamepadMouseConfig` 结构体差异化。

**Tech Stack:** Objective-C, UIKit, GameController.framework, Limelight-C protocol library

**设计文档:** `docs/plans/2026-03-01-mouse-keyboard-mode-design.md`

---

## 参考信息

### Limelight API 常量 (moonlight-common-c/src/Limelight.h)

```c
// 鼠标按键动作
#define BUTTON_ACTION_PRESS   0x07
#define BUTTON_ACTION_RELEASE 0x08
#define BUTTON_LEFT   0x01
#define BUTTON_MIDDLE 0x02
#define BUTTON_RIGHT  0x03

// 键盘动作
#define KEY_ACTION_DOWN 0x03
#define KEY_ACTION_UP   0x04
#define MODIFIER_SHIFT  0x01
#define MODIFIER_CTRL   0x02
#define MODIFIER_ALT    0x04
#define MODIFIER_META   0x08

// 手柄按键标志
#define A_FLAG      0x1000
#define B_FLAG      0x2000
#define X_FLAG      0x4000
#define Y_FLAG      0x8000
#define LB_FLAG     0x0100
#define RB_FLAG     0x0200
#define PLAY_FLAG   0x0010
#define BACK_FLAG   0x0020
#define SPECIAL_FLAG 0x0400
```

### API 函数签名

```c
int LiSendMouseMoveEvent(short deltaX, short deltaY);
int LiSendMouseButtonEvent(char action, int button);
int LiSendHighResScrollEvent(short scrollAmount);
int LiSendHighResHScrollEvent(short scrollAmount);
int LiSendKeyboardEvent(short keyCode, char keyAction, char modifiers);
```

### Controller 对象关键属性 (Controller.h)

```objc
@property (nonatomic) int lastButtonFlags;
@property (nonatomic) unsigned char lastLeftTrigger;   // 0-255
@property (nonatomic) unsigned char lastRightTrigger;  // 0-255
@property (nonatomic) short lastLeftStickX;            // -32766 ~ 32766
@property (nonatomic) short lastLeftStickY;
@property (nonatomic) short lastRightStickX;
@property (nonatomic) short lastRightStickY;
```

---

## Task 1: 创建 GamepadMouseConfig 平台参数头文件

**Files:**
- Create: `Limelight/Input/GamepadMouseConfig.h`

**Step 1: 创建平台参数结构体头文件**

```objc
//
//  GamepadMouseConfig.h
//  Moonlight
//
//  平台差异化参数配置（iOS vs tvOS）
//

#ifndef GamepadMouseConfig_h
#define GamepadMouseConfig_h

#import <Foundation/Foundation.h>

typedef struct {
    NSTimeInterval pollInterval;  // 鼠标移动采样间隔
    float sensitivity;            // 灵敏度乘数
    float deadzone;               // 摇杆死区
    float scrollSpeed;            // 滚轮速度
} GamepadMouseConfig;

static inline GamepadMouseConfig GamepadMouseConfigDefault(void) {
#if TARGET_OS_TV
    return (GamepadMouseConfig){
        .pollInterval = 1.0 / 240.0,
        .sensitivity = 4.0f,
        .deadzone = 0.1f,
        .scrollSpeed = 2.0f,
    };
#else
    return (GamepadMouseConfig){
        .pollInterval = 1.0 / 120.0,
        .sensitivity = 3.0f,
        .deadzone = 0.1f,
        .scrollSpeed = 1.5f,
    };
#endif
}

#endif /* GamepadMouseConfig_h */
```

**Step 2: 将文件添加到 Xcode 项目**

在 `Moonlight.xcodeproj/project.pbxproj` 中，将 `GamepadMouseConfig.h` 添加到 `Moonlight` 和 `Moonlight TV` 两个 target 的 Header 文件组中。注意保持与其他 Input 目录下头文件一致的 group 路径。

**Step 3: 验证编译**

Run: `xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Limelight/Input/GamepadMouseConfig.h Moonlight.xcodeproj/project.pbxproj
git commit -m "添加 GamepadMouseConfig 平台差异化参数头文件

iOS 120Hz 采样、灵敏度 3.0；tvOS 240Hz 采样、灵敏度 4.0。
通过编译期 TARGET_OS_TV 宏自动选择参数。"
```

---

## Task 2: 创建 GamepadMouseHandler 核心类（模式切换 + 鼠标移动）

**Files:**
- Create: `Limelight/Input/GamepadMouseHandler.h`
- Create: `Limelight/Input/GamepadMouseHandler.m`

**Step 1: 创建 GamepadMouseHandler 头文件**

```objc
//
//  GamepadMouseHandler.h
//  Moonlight
//
//  手柄模拟鼠标模式核心处理类
//

#import <Foundation/Foundation.h>
#import "Controller.h"
#import "GamepadMouseConfig.h"

@protocol GamepadMouseDelegate <NSObject>

// 鼠标模式开关状态变化
- (void)mouseModeDidChange:(BOOL)enabled;

// 请求显示/隐藏虚拟键盘
- (void)requestToggleKeyboard;

@end

@interface GamepadMouseHandler : NSObject

@property (nonatomic, readonly) BOOL mouseMode;
@property (nonatomic, readonly) BOOL keyboardVisible;
@property (nonatomic, weak) id<GamepadMouseDelegate> delegate;

- (instancetype)initWithDelegate:(id<GamepadMouseDelegate>)delegate;

// 切换鼠标模式
- (void)toggleMouseMode;

// 通知键盘显示状态（由外部设置）
- (void)setKeyboardVisible:(BOOL)visible;

// 处理手柄输入，返回 YES 表示已消费
- (BOOL)handleGamepadInput:(Controller*)controller;

// 检测是否应切换鼠标模式（LB+RB 组合键）
- (BOOL)shouldToggleMouseMode:(Controller*)controller;

// 清理资源
- (void)cleanup;

@end
```

**Step 2: 创建 GamepadMouseHandler 实现文件**

```objc
//
//  GamepadMouseHandler.m
//  Moonlight
//
//  手柄模拟鼠标模式核心处理类
//

#import "GamepadMouseHandler.h"
#include <Limelight.h>

// 扳机阈值：超过此值视为按下
static const unsigned char TRIGGER_PRESS_THRESHOLD = 128;

@implementation GamepadMouseHandler {
    GamepadMouseConfig _config;

    // 鼠标移动轮询定时器
    NSTimer *_pollTimer;

    // 浮点累积（避免小偏转截断）
    float _accumulatedMouseX;
    float _accumulatedMouseY;
    float _accumulatedScrollX;
    float _accumulatedScrollY;

    // 当前跟踪的手柄（用于定时器轮询）
    __weak Controller *_trackedController;

    // LB+RB 切换防抖
    BOOL _toggleCooldown;

    // 按键状态跟踪（用于检测按下/松开边沿）
    BOOL _aPressed;
    BOOL _xPressed;
    BOOL _yPressed;
    BOOL _ltPressed;
    BOOL _rtPressed;
}

- (instancetype)initWithDelegate:(id<GamepadMouseDelegate>)delegate {
    self = [super init];
    if (self) {
        _config = GamepadMouseConfigDefault();
        _delegate = delegate;
        _mouseMode = NO;
        _keyboardVisible = NO;
        _toggleCooldown = NO;
    }
    return self;
}

#pragma mark - 模式切换

- (void)toggleMouseMode {
    _mouseMode = !_mouseMode;

    if (_mouseMode) {
        [self startPolling];
    } else {
        [self stopPolling];
        // 退出鼠标模式时也关闭键盘
        if (_keyboardVisible) {
            _keyboardVisible = NO;
        }
    }

    // 重置按键状态
    [self resetButtonStates];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate mouseModeDidChange:self->_mouseMode];
    });
}

- (void)setKeyboardVisible:(BOOL)visible {
    _keyboardVisible = visible;
}

- (BOOL)shouldToggleMouseMode:(Controller*)controller {
    BOOL lbPressed = (controller.lastButtonFlags & LB_FLAG) != 0;
    BOOL rbPressed = (controller.lastButtonFlags & RB_FLAG) != 0;
    BOOL noOtherButtons = (controller.lastButtonFlags & ~(LB_FLAG | RB_FLAG)) == 0;
    // 摇杆和扳机也需要在中立位置，避免误触发
    BOOL sticksNeutral = abs(controller.lastLeftStickX) < 3000 &&
                         abs(controller.lastLeftStickY) < 3000 &&
                         abs(controller.lastRightStickX) < 3000 &&
                         abs(controller.lastRightStickY) < 3000;
    BOOL triggersNeutral = controller.lastLeftTrigger < TRIGGER_PRESS_THRESHOLD &&
                           controller.lastRightTrigger < TRIGGER_PRESS_THRESHOLD;

    if (lbPressed && rbPressed && noOtherButtons && sticksNeutral && triggersNeutral && !_toggleCooldown) {
        _toggleCooldown = YES;
        return YES;
    }
    if (!lbPressed || !rbPressed) {
        _toggleCooldown = NO;
    }
    return NO;
}

#pragma mark - 输入处理

- (BOOL)handleGamepadInput:(Controller*)controller {
    if (!_mouseMode) {
        return NO;
    }

    _trackedController = controller;

    // 键盘可见时不处理鼠标按键，只跟踪手柄引用供键盘导航用
    if (_keyboardVisible) {
        return YES;  // 消费输入，阻止发送到主机
    }

    // 处理按钮事件（边沿检测）
    [self handleButtonEvents:controller];

    // 摇杆移动在定时器中处理（pollMouseMovement）

    return YES;  // 消费输入
}

- (void)handleButtonEvents:(Controller*)controller {
    // A 键 → 鼠标左键
    BOOL aCurrentlyPressed = (controller.lastButtonFlags & A_FLAG) != 0;
    if (aCurrentlyPressed != _aPressed) {
        _aPressed = aCurrentlyPressed;
        LiSendMouseButtonEvent(
            aCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_LEFT
        );
    }

    // X 键 → 鼠标右键
    BOOL xCurrentlyPressed = (controller.lastButtonFlags & X_FLAG) != 0;
    if (xCurrentlyPressed != _xPressed) {
        _xPressed = xCurrentlyPressed;
        LiSendMouseButtonEvent(
            xCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_RIGHT
        );
    }

    // Y 键 → 切换虚拟键盘（仅检测按下边沿）
    BOOL yCurrentlyPressed = (controller.lastButtonFlags & Y_FLAG) != 0;
    if (yCurrentlyPressed && !_yPressed) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate requestToggleKeyboard];
        });
    }
    _yPressed = yCurrentlyPressed;

    // LT → 备用鼠标左键
    BOOL ltCurrentlyPressed = controller.lastLeftTrigger >= TRIGGER_PRESS_THRESHOLD;
    if (ltCurrentlyPressed != _ltPressed) {
        _ltPressed = ltCurrentlyPressed;
        LiSendMouseButtonEvent(
            ltCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_LEFT
        );
    }

    // RT → 备用鼠标右键
    BOOL rtCurrentlyPressed = controller.lastRightTrigger >= TRIGGER_PRESS_THRESHOLD;
    if (rtCurrentlyPressed != _rtPressed) {
        _rtPressed = rtCurrentlyPressed;
        LiSendMouseButtonEvent(
            rtCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_RIGHT
        );
    }
}

#pragma mark - 鼠标移动轮询

- (void)startPolling {
    [self stopPolling];
    _pollTimer = [NSTimer scheduledTimerWithTimeInterval:_config.pollInterval
                                                 target:self
                                               selector:@selector(pollMouseMovement)
                                               userInfo:nil
                                                repeats:YES];
    // 让定时器在 RunLoop 的 CommonModes 中运行，避免被 UI 事件阻塞
    [[NSRunLoop currentRunLoop] addTimer:_pollTimer forMode:NSRunLoopCommonModes];
}

- (void)stopPolling {
    [_pollTimer invalidate];
    _pollTimer = nil;
    _accumulatedMouseX = 0;
    _accumulatedMouseY = 0;
    _accumulatedScrollX = 0;
    _accumulatedScrollY = 0;
}

- (void)pollMouseMovement {
    Controller *controller = _trackedController;
    if (!controller || !_mouseMode || _keyboardVisible) {
        return;
    }

    [self processMouseMove:controller];
    [self processScroll:controller];
}

- (void)processMouseMove:(Controller*)controller {
    // 归一化到 -1.0 ~ 1.0
    float x = controller.lastLeftStickX / 32766.0f;
    float y = controller.lastLeftStickY / 32766.0f;

    // 死区过滤
    if (fabsf(x) < _config.deadzone) x = 0;
    if (fabsf(y) < _config.deadzone) y = 0;

    if (x == 0 && y == 0) return;

    // 立方加速曲线
    float multiplier = _config.sensitivity / 4.0f;
    float scaledX = x * multiplier;
    float scaledY = -y * multiplier;  // Y 轴取反（摇杆上为正，屏幕上为负）
    float deltaX = scaledX * scaledX * scaledX;  // pow(x,3) 保留符号
    float deltaY = scaledY * scaledY * scaledY;

    // 保留符号（立方运算已保留）
    // scaledX * scaledX * scaledX 等价于 copysignf(powf(fabsf(scaledX), 3), scaledX)

    // 浮点累积
    _accumulatedMouseX += deltaX;
    _accumulatedMouseY += deltaY;

    short sendX = (short)_accumulatedMouseX;
    short sendY = (short)_accumulatedMouseY;

    _accumulatedMouseX -= sendX;
    _accumulatedMouseY -= sendY;

    if (sendX != 0 || sendY != 0) {
        LiSendMouseMoveEvent(sendX, sendY);
    }
}

- (void)processScroll:(Controller*)controller {
    // 归一化
    float scrollX = controller.lastRightStickX / 32766.0f;
    float scrollY = controller.lastRightStickY / 32766.0f;

    // 死区过滤
    if (fabsf(scrollX) < _config.deadzone) scrollX = 0;
    if (fabsf(scrollY) < _config.deadzone) scrollY = 0;

    if (scrollX == 0 && scrollY == 0) return;

    // 线性映射（滚轮不需要加速曲线）
    _accumulatedScrollY += scrollY * _config.scrollSpeed;
    _accumulatedScrollX += scrollX * _config.scrollSpeed;

    short sendScrollY = (short)_accumulatedScrollY;
    short sendScrollX = (short)_accumulatedScrollX;

    _accumulatedScrollY -= sendScrollY;
    _accumulatedScrollX -= sendScrollX;

    if (sendScrollY != 0) {
        LiSendHighResScrollEvent(sendScrollY);
    }
    if (sendScrollX != 0) {
        LiSendHighResHScrollEvent(sendScrollX);
    }
}

#pragma mark - 辅助方法

- (void)resetButtonStates {
    _aPressed = NO;
    _xPressed = NO;
    _yPressed = NO;
    _ltPressed = NO;
    _rtPressed = NO;
}

- (void)cleanup {
    [self stopPolling];
    _mouseMode = NO;
    _keyboardVisible = NO;
    [self resetButtonStates];
}

@end
```

**Step 3: 将文件添加到 Xcode 项目**

将 `GamepadMouseHandler.h` 和 `GamepadMouseHandler.m` 添加到 `Moonlight` 和 `Moonlight TV` 两个 target 中，放在 `Limelight/Input` group 下。

**Step 4: 验证编译**

Run: `xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Limelight/Input/GamepadMouseHandler.h Limelight/Input/GamepadMouseHandler.m Moonlight.xcodeproj/project.pbxproj
git commit -m "添加 GamepadMouseHandler 核心类

实现手柄模拟鼠标模式的完整逻辑：
- LB+RB 组合键切换模式（含防抖和中立位检测）
- 左摇杆立方加速曲线控制鼠标移动
- A/LT 鼠标左键，X/RT 鼠标右键（边沿检测）
- 右摇杆控制滚轮
- Y 键请求虚拟键盘
- 定时器轮询：iOS 120Hz / tvOS 240Hz"
```

---

## Task 3: 集成 GamepadMouseHandler 到 ControllerSupport

**Files:**
- Modify: `Limelight/Input/ControllerSupport.h`
- Modify: `Limelight/Input/ControllerSupport.m`

**Step 1: 修改 ControllerSupport.h**

在 `ControllerSupport.h` 中添加 `GamepadMouseHandler` 的引用和 delegate 协议转发：

```objc
// 在 #import "Controller.h" 之后添加
#import "GamepadMouseHandler.h"

// 在 ControllerSupportDelegate 协议中添加方法
@protocol ControllerSupportDelegate <NSObject>

- (void) gamepadPresenceChanged;
- (void) mousePresenceChanged;
- (void) streamExitRequested;

// 新增：鼠标模式状态变化
- (void) mouseModeDidChange:(BOOL)enabled;
// 新增：请求显示/隐藏虚拟键盘
- (void) requestToggleKeyboard;

@end

// 在 @interface ControllerSupport 中添加
@property (nonatomic, readonly) GamepadMouseHandler *gamepadMouseHandler;
```

**Step 2: 修改 ControllerSupport.m**

在实现文件中创建 `GamepadMouseHandler` 并修改 `updateFinished:` 方法：

2a. 在 `@implementation` 块中，让 `ControllerSupport` 遵循 `GamepadMouseDelegate`：

```objc
@interface ControllerSupport () <GamepadMouseDelegate>
@end
```

2b. 在 `initWithConfig:delegate:` 方法中初始化 `GamepadMouseHandler`：

```objc
// 在 init 方法的末尾，_controllerStreamLock 初始化之后添加
_gamepadMouseHandler = [[GamepadMouseHandler alloc] initWithDelegate:self];
```

2c. 修改 `updateFinished:` 方法，在退出组合键检测之后、`LiSendMultiControllerEvent` 之前插入鼠标模式拦截逻辑：

```objc
-(void) updateFinished:(Controller*)controller
{
    BOOL exitRequested = NO;

    [_controllerStreamLock lock];
    @synchronized(controller) {
        // 退出组合键始终优先（现有逻辑保持不变）
        if (controller.lastButtonFlags == (PLAY_FLAG | BACK_FLAG | LB_FLAG | RB_FLAG)) {
            controller.lastButtonFlags = 0;
            exitRequested = YES;
        }

        // === 新增：鼠标模式切换检测 ===
        if (!exitRequested && [_gamepadMouseHandler shouldToggleMouseMode:controller]) {
            [_gamepadMouseHandler toggleMouseMode];
            // 切换时不发送手柄事件
            [_controllerStreamLock unlock];
            return;
        }

        // === 新增：鼠标模式下拦截手柄输入 ===
        if (!exitRequested && [_gamepadMouseHandler handleGamepadInput:controller]) {
            // 输入已被鼠标模式消费
            [_controllerStreamLock unlock];
            return;
        }

        // 正常手柄模式（现有逻辑保持不变）
        if ([self reportControllerArrival:controller]) {
            // ... 现有的 LiSendMultiControllerEvent 逻辑 ...
        }
    }
    [_controllerStreamLock unlock];

    if (exitRequested) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self->_delegate streamExitRequested];
        });
    }
}
```

2d. 实现 `GamepadMouseDelegate` 方法：

```objc
#pragma mark - GamepadMouseDelegate

- (void)mouseModeDidChange:(BOOL)enabled {
    [_delegate mouseModeDidChange:enabled];
}

- (void)requestToggleKeyboard {
    [_delegate requestToggleKeyboard];
}
```

2e. 在 `cleanup` 方法中清理 `GamepadMouseHandler`：

```objc
-(void) cleanup {
    [_gamepadMouseHandler cleanup];
    // ... 现有清理逻辑 ...
}
```

**Step 3: 验证编译**

Run: `xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Limelight/Input/ControllerSupport.h Limelight/Input/ControllerSupport.m
git commit -m "集成 GamepadMouseHandler 到 ControllerSupport

在 updateFinished: 中拦截手柄输入：
- 退出组合键始终优先
- LB+RB 触发鼠标模式切换
- 鼠标模式下消费手柄输入，不发送 LiSendMultiControllerEvent
- 通过 ControllerSupportDelegate 转发模式变化和键盘请求"
```

---

## Task 4: 创建 KeyboardOverlayView 虚拟键盘覆盖层

**Files:**
- Create: `Limelight/Input/KeyboardOverlayView.h`
- Create: `Limelight/Input/KeyboardOverlayView.m`

**Step 1: 创建 KeyboardOverlayView 头文件**

```objc
//
//  KeyboardOverlayView.h
//  Moonlight
//
//  虚拟键盘覆盖层，支持 iOS 和 tvOS
//

#import <UIKit/UIKit.h>

@interface KeyboardOverlayView : UIView

@property (nonatomic, readonly) BOOL isVisible;

- (void)showAnimated:(BOOL)animated;
- (void)dismissAnimated:(BOOL)animated;

@end
```

**Step 2: 创建 KeyboardOverlayView 实现文件**

这是最大的文件。关键设计点：
- 19列 x 6行的按键网格
- 每个按键是一个 `UIButton`，用 `tag` 存储 Windows VK code
- 修饰键（Shift/Ctrl/Alt）使用 toggle 状态
- 按键按下时发送 `LiSendKeyboardEvent`
- 半透明背景覆盖层

```objc
//
//  KeyboardOverlayView.m
//  Moonlight
//
//  虚拟键盘覆盖层，支持 iOS 和 tvOS
//

#import "KeyboardOverlayView.h"
#include <Limelight.h>

// 键盘按键定义
typedef struct {
    const char *label;           // 显示文字
    const char *shiftLabel;      // Shift 时显示文字（NULL 表示与 label 相同）
    short vkCode;                // Windows VK code
    int columnSpan;              // 占据列数（默认 1）
} KeyDef;

// Windows VK codes
#define VK_ESCAPE   0x1B
#define VK_F1       0x70
#define VK_F2       0x71
#define VK_F3       0x72
#define VK_F4       0x73
#define VK_F5       0x74
#define VK_F6       0x75
#define VK_F7       0x76
#define VK_F8       0x77
#define VK_F9       0x78
#define VK_F10      0x79
#define VK_F11      0x7A
#define VK_F12      0x7B
#define VK_OEM_3    0xC0  // `~
#define VK_0        0x30
#define VK_1        0x31
#define VK_2        0x32
#define VK_3        0x33
#define VK_4        0x34
#define VK_5        0x35
#define VK_6        0x36
#define VK_7        0x37
#define VK_8        0x38
#define VK_9        0x39
#define VK_OEM_MINUS 0xBD
#define VK_OEM_PLUS  0xBB
#define VK_BACK     0x08  // Backspace
#define VK_TAB      0x09
#define VK_OEM_4    0xDB  // [{
#define VK_OEM_6    0xDD  // ]}
#define VK_OEM_5    0xDC  // \|
#define VK_DELETE   0x2E
#define VK_CAPITAL  0x14  // Caps Lock
#define VK_OEM_1    0xBA  // ;:
#define VK_OEM_7    0xDE  // '"
#define VK_RETURN   0x0D
#define VK_SHIFT    0x10
#define VK_OEM_COMMA  0xBC
#define VK_OEM_PERIOD 0xBE
#define VK_OEM_2    0xBF  // /?
#define VK_UP       0x26
#define VK_CONTROL  0x11
#define VK_LWIN     0x5B
#define VK_MENU     0x12  // Alt
#define VK_SPACE    0x20
#define VK_LEFT     0x25
#define VK_DOWN     0x28
#define VK_RIGHT    0x27
#define VK_INSERT   0x2D
#define VK_HOME     0x24
#define VK_PRIOR    0x21  // Page Up
#define VK_END      0x23
#define VK_NEXT     0x22  // Page Down

// 标记修饰键的特殊 tag 偏移（高 16 位标记类型）
#define TAG_MODIFIER_BIT 0x10000
#define TAG_SHIFT   (TAG_MODIFIER_BIT | VK_SHIFT)
#define TAG_CTRL    (TAG_MODIFIER_BIT | VK_CONTROL)
#define TAG_ALT     (TAG_MODIFIER_BIT | VK_MENU)
#define TAG_CAPS    (TAG_MODIFIER_BIT | VK_CAPITAL)

// 键盘行定义
static const KeyDef kRow0[] = {
    {"Esc", NULL, VK_ESCAPE, 1},
    {"F1", NULL, VK_F1, 1}, {"F2", NULL, VK_F2, 1}, {"F3", NULL, VK_F3, 1}, {"F4", NULL, VK_F4, 1},
    {"F5", NULL, VK_F5, 1}, {"F6", NULL, VK_F6, 1}, {"F7", NULL, VK_F7, 1}, {"F8", NULL, VK_F8, 1},
    {"F9", NULL, VK_F9, 1}, {"F10", NULL, VK_F10, 1}, {"F11", NULL, VK_F11, 1}, {"F12", NULL, VK_F12, 1},
};
static const int kRow0Count = sizeof(kRow0) / sizeof(kRow0[0]);

static const KeyDef kRow1[] = {
    {"`", "~", VK_OEM_3, 1},
    {"1", "!", VK_1, 1}, {"2", "@", VK_2, 1}, {"3", "#", VK_3, 1}, {"4", "$", VK_4, 1},
    {"5", "%", VK_5, 1}, {"6", "^", VK_6, 1}, {"7", "&", VK_7, 1}, {"8", "*", VK_8, 1},
    {"9", "(", VK_9, 1}, {"0", ")", VK_0, 1}, {"-", "_", VK_OEM_MINUS, 1}, {"=", "+", VK_OEM_PLUS, 1},
    {"Bksp", NULL, VK_BACK, 2},
    {"Ins", NULL, VK_INSERT, 1}, {"Home", NULL, VK_HOME, 1}, {"PgUp", NULL, VK_PRIOR, 1},
};
static const int kRow1Count = sizeof(kRow1) / sizeof(kRow1[0]);

static const KeyDef kRow2[] = {
    {"Tab", NULL, VK_TAB, 2},
    {"Q", NULL, 0x51, 1}, {"W", NULL, 0x57, 1}, {"E", NULL, 0x45, 1}, {"R", NULL, 0x52, 1},
    {"T", NULL, 0x54, 1}, {"Y", NULL, 0x59, 1}, {"U", NULL, 0x55, 1}, {"I", NULL, 0x49, 1},
    {"O", NULL, 0x4F, 1}, {"P", NULL, 0x50, 1}, {"[", "{", VK_OEM_4, 1}, {"]", "}", VK_OEM_6, 1},
    {"\\", "|", VK_OEM_5, 1},
    {"Del", NULL, VK_DELETE, 1}, {"End", NULL, VK_END, 1}, {"PgDn", NULL, VK_NEXT, 1},
};
static const int kRow2Count = sizeof(kRow2) / sizeof(kRow2[0]);

static const KeyDef kRow3[] = {
    {"Caps", NULL, VK_CAPITAL, 2},
    {"A", NULL, 0x41, 1}, {"S", NULL, 0x53, 1}, {"D", NULL, 0x44, 1}, {"F", NULL, 0x46, 1},
    {"G", NULL, 0x47, 1}, {"H", NULL, 0x48, 1}, {"J", NULL, 0x4A, 1}, {"K", NULL, 0x4B, 1},
    {"L", NULL, 0x4C, 1}, {";", ":", VK_OEM_1, 1}, {"'", "\"", VK_OEM_7, 1},
    {"Enter", NULL, VK_RETURN, 3},
};
static const int kRow3Count = sizeof(kRow3) / sizeof(kRow3[0]);

static const KeyDef kRow4[] = {
    {"Shift", NULL, VK_SHIFT, 3},
    {"Z", NULL, 0x5A, 1}, {"X", NULL, 0x58, 1}, {"C", NULL, 0x43, 1}, {"V", NULL, 0x56, 1},
    {"B", NULL, 0x42, 1}, {"N", NULL, 0x4E, 1}, {"M", NULL, 0x4D, 1},
    {",", "<", VK_OEM_COMMA, 1}, {".", ">", VK_OEM_PERIOD, 1}, {"/", "?", VK_OEM_2, 1},
    {"Shift", NULL, VK_SHIFT, 2},
    {"\u2191", NULL, VK_UP, 1},  // ↑
};
static const int kRow4Count = sizeof(kRow4) / sizeof(kRow4[0]);

static const KeyDef kRow5[] = {
    {"Ctrl", NULL, VK_CONTROL, 2},
    {"Win", NULL, VK_LWIN, 1},
    {"Alt", NULL, VK_MENU, 2},
    {"Space", NULL, VK_SPACE, 7},
    {"Alt", NULL, VK_MENU, 2},
    {"Ctrl", NULL, VK_CONTROL, 2},
    {"\u2190", NULL, VK_LEFT, 1},   // ←
    {"\u2193", NULL, VK_DOWN, 1},   // ↓
    {"\u2192", NULL, VK_RIGHT, 1},  // →
};
static const int kRow5Count = sizeof(kRow5) / sizeof(kRow5[0]);

@implementation KeyboardOverlayView {
    UIView *_backgroundView;
    UIView *_keyboardContainer;
    NSMutableArray<UIButton *> *_allKeys;

    // 修饰键状态
    BOOL _shiftActive;
    BOOL _ctrlActive;
    BOOL _altActive;
    BOOL _capsActive;

    // 修饰键按钮引用（用于更新高亮）
    NSMutableArray<UIButton *> *_shiftButtons;
    NSMutableArray<UIButton *> *_ctrlButtons;
    NSMutableArray<UIButton *> *_altButtons;
    UIButton *_capsButton;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _isVisible = NO;
        _allKeys = [NSMutableArray array];
        _shiftButtons = [NSMutableArray array];
        _ctrlButtons = [NSMutableArray array];
        _altButtons = [NSMutableArray array];
        self.alpha = 0;
        self.hidden = YES;
        [self setupKeyboard];
    }
    return self;
}

- (void)setupKeyboard {
    // 半透明背景
    _backgroundView = [[UIView alloc] initWithFrame:self.bounds];
    _backgroundView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
    _backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:_backgroundView];

    // 键盘容器（底部对齐）
    _keyboardContainer = [[UIView alloc] init];
    _keyboardContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_keyboardContainer];

    [NSLayoutConstraint activateConstraints:@[
        [_keyboardContainer.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:20],
        [_keyboardContainer.trailingAnchor constraintEqualToAnchor:self.trailingAnchor constant:-20],
        [_keyboardContainer.bottomAnchor constraintEqualToAnchor:self.bottomAnchor constant:-20],
    ]];

    // 创建所有键盘行
    NSArray *rows = @[
        [self createRowButtons:kRow0 count:kRow0Count],
        [self createRowButtons:kRow1 count:kRow1Count],
        [self createRowButtons:kRow2 count:kRow2Count],
        [self createRowButtons:kRow3 count:kRow3Count],
        [self createRowButtons:kRow4 count:kRow4Count],
        [self createRowButtons:kRow5 count:kRow5Count],
    ];

    UIView *previousRow = nil;
    CGFloat rowHeight;
#if TARGET_OS_TV
    rowHeight = 52;
#else
    rowHeight = 36;
#endif

    for (NSUInteger i = 0; i < rows.count; i++) {
        UIView *rowView = rows[i];
        rowView.translatesAutoresizingMaskIntoConstraints = NO;
        [_keyboardContainer addSubview:rowView];

        [NSLayoutConstraint activateConstraints:@[
            [rowView.leadingAnchor constraintEqualToAnchor:_keyboardContainer.leadingAnchor],
            [rowView.trailingAnchor constraintEqualToAnchor:_keyboardContainer.trailingAnchor],
            [rowView.heightAnchor constraintEqualToConstant:rowHeight],
        ]];

        if (previousRow) {
            [rowView.topAnchor constraintEqualToAnchor:previousRow.bottomAnchor constant:2].active = YES;
        } else {
            [rowView.topAnchor constraintEqualToAnchor:_keyboardContainer.topAnchor].active = YES;
        }

        if (i == rows.count - 1) {
            [rowView.bottomAnchor constraintEqualToAnchor:_keyboardContainer.bottomAnchor].active = YES;
        }

        previousRow = rowView;
    }
}

- (UIView *)createRowButtons:(const KeyDef *)keyDefs count:(int)count {
    UIView *rowView = [[UIView alloc] init];

    UIView *previousButton = nil;
    int totalColumns = 0;
    for (int i = 0; i < count; i++) {
        totalColumns += keyDefs[i].columnSpan > 0 ? keyDefs[i].columnSpan : 1;
    }

    // 第一遍：创建按钮并设置约束
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];

    for (int i = 0; i < count; i++) {
        KeyDef def = keyDefs[i];
        int span = def.columnSpan > 0 ? def.columnSpan : 1;

        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.translatesAutoresizingMaskIntoConstraints = NO;

        NSString *label = [NSString stringWithUTF8String:def.label];
        [button setTitle:label forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

#if TARGET_OS_TV
        button.titleLabel.font = [UIFont systemFontOfSize:18];
#else
        button.titleLabel.font = [UIFont systemFontOfSize:12];
#endif

        button.backgroundColor = [UIColor colorWithWhite:0.3 alpha:0.8];
        button.layer.cornerRadius = 4;
        button.clipsToBounds = YES;

        // 用 tag 存储 VK code（修饰键用特殊标记）
        BOOL isModifier = (def.vkCode == VK_SHIFT || def.vkCode == VK_CONTROL ||
                           def.vkCode == VK_MENU || def.vkCode == VK_CAPITAL);
        if (isModifier) {
            button.tag = TAG_MODIFIER_BIT | def.vkCode;
        } else {
            button.tag = def.vkCode;
        }

        [button addTarget:self action:@selector(keyPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];

        [rowView addSubview:button];
        [buttons addObject:button];
        [_allKeys addObject:button];

        // 跟踪修饰键按钮
        if (def.vkCode == VK_SHIFT) [_shiftButtons addObject:button];
        else if (def.vkCode == VK_CONTROL) [_ctrlButtons addObject:button];
        else if (def.vkCode == VK_MENU) [_altButtons addObject:button];
        else if (def.vkCode == VK_CAPITAL) _capsButton = button;

        // 保存 shiftLabel 到 accessibilityValue
        if (def.shiftLabel != NULL) {
            button.accessibilityValue = [NSString stringWithUTF8String:def.shiftLabel];
        }

        // 约束
        [NSLayoutConstraint activateConstraints:@[
            [button.topAnchor constraintEqualToAnchor:rowView.topAnchor],
            [button.bottomAnchor constraintEqualToAnchor:rowView.bottomAnchor],
        ]];

        if (previousButton) {
            [button.leadingAnchor constraintEqualToAnchor:previousButton.trailingAnchor constant:2].active = YES;
        } else {
            [button.leadingAnchor constraintEqualToAnchor:rowView.leadingAnchor].active = YES;
        }

        // 宽度比例约束
        if (span == 1) {
            [button.widthAnchor constraintEqualToAnchor:rowView.widthAnchor
                                             multiplier:(1.0 / totalColumns)
                                               constant:-2].active = YES;
        } else {
            [button.widthAnchor constraintEqualToAnchor:rowView.widthAnchor
                                             multiplier:((float)span / totalColumns)
                                               constant:-2].active = YES;
        }

        if (i == count - 1) {
            [button.trailingAnchor constraintEqualToAnchor:rowView.trailingAnchor].active = YES;
        }

        previousButton = button;
    }

    return rowView;
}

#pragma mark - 按键处理

- (void)keyPressed:(UIButton *)sender {
    NSInteger tag = sender.tag;

    if (tag & TAG_MODIFIER_BIT) {
        // 修饰键：toggle 状态
        short vk = tag & 0xFFFF;
        [self toggleModifier:vk];
    } else {
        // 普通键：发送按下+松开
        short vkCode = (short)tag;
        char modifiers = [self currentModifiers];

        LiSendKeyboardEvent(0x8000 | vkCode, KEY_ACTION_DOWN, modifiers);

        // 延迟发送 key up
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)),
                       dispatch_get_main_queue(), ^{
            LiSendKeyboardEvent(0x8000 | vkCode, KEY_ACTION_UP, modifiers);
        });

        // 普通键按下后自动取消 Shift（模拟物理键盘行为）
        if (_shiftActive && !_capsActive) {
            _shiftActive = NO;
            [self updateModifierHighlights];
            [self updateKeyLabels];
        }
    }
}

- (void)toggleModifier:(short)vkCode {
    switch (vkCode) {
        case VK_SHIFT:
            _shiftActive = !_shiftActive;
            [self updateKeyLabels];
            break;
        case VK_CONTROL:
            _ctrlActive = !_ctrlActive;
            break;
        case VK_MENU:
            _altActive = !_altActive;
            break;
        case VK_CAPITAL:
            _capsActive = !_capsActive;
            // Caps Lock 需要发送按下+松开事件给主机
            LiSendKeyboardEvent(0x8000 | VK_CAPITAL, KEY_ACTION_DOWN, 0);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(50 * NSEC_PER_MSEC)),
                           dispatch_get_main_queue(), ^{
                LiSendKeyboardEvent(0x8000 | VK_CAPITAL, KEY_ACTION_UP, 0);
            });
            break;
    }
    [self updateModifierHighlights];
}

- (char)currentModifiers {
    char modifiers = 0;
    if (_shiftActive) modifiers |= MODIFIER_SHIFT;
    if (_ctrlActive) modifiers |= MODIFIER_CTRL;
    if (_altActive) modifiers |= MODIFIER_ALT;
    return modifiers;
}

- (void)updateModifierHighlights {
    UIColor *activeColor = [UIColor colorWithRed:0.2 green:0.4 blue:0.8 alpha:0.9];
    UIColor *inactiveColor = [UIColor colorWithWhite:0.3 alpha:0.8];

    for (UIButton *btn in _shiftButtons) {
        btn.backgroundColor = _shiftActive ? activeColor : inactiveColor;
    }
    for (UIButton *btn in _ctrlButtons) {
        btn.backgroundColor = _ctrlActive ? activeColor : inactiveColor;
    }
    for (UIButton *btn in _altButtons) {
        btn.backgroundColor = _altActive ? activeColor : inactiveColor;
    }
    if (_capsButton) {
        _capsButton.backgroundColor = _capsActive ? activeColor : inactiveColor;
    }
}

- (void)updateKeyLabels {
    BOOL showShift = _shiftActive || _capsActive;

    for (UIButton *btn in _allKeys) {
        if (btn.tag & TAG_MODIFIER_BIT) continue;  // 跳过修饰键

        if (showShift && btn.accessibilityValue.length > 0) {
            [btn setTitle:btn.accessibilityValue forState:UIControlStateNormal];
        } else {
            // 恢复原始标签：对字母键 toggle 大小写
            NSString *title = btn.currentTitle;
            if (title.length == 1) {
                unichar c = [title characterAtIndex:0];
                if (c >= 'A' && c <= 'Z') {
                    // 单字母键
                    if (showShift) {
                        [btn setTitle:[title uppercaseString] forState:UIControlStateNormal];
                    } else {
                        [btn setTitle:[title lowercaseString] forState:UIControlStateNormal];
                    }
                }
            }
        }
    }
}

#pragma mark - 显示/隐藏

- (void)showAnimated:(BOOL)animated {
    if (_isVisible) return;
    _isVisible = YES;
    self.hidden = NO;

    if (animated) {
        _keyboardContainer.transform = CGAffineTransformMakeTranslation(0, 300);
        [UIView animateWithDuration:0.25 animations:^{
            self.alpha = 1;
            self->_keyboardContainer.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.alpha = 1;
    }
}

- (void)dismissAnimated:(BOOL)animated {
    if (!_isVisible) return;
    _isVisible = NO;

    if (animated) {
        [UIView animateWithDuration:0.2 animations:^{
            self.alpha = 0;
            self->_keyboardContainer.transform = CGAffineTransformMakeTranslation(0, 300);
        } completion:^(BOOL finished) {
            self.hidden = YES;
            self->_keyboardContainer.transform = CGAffineTransformIdentity;
        }];
    } else {
        self.alpha = 0;
        self.hidden = YES;
    }
}

#pragma mark - Focus Engine (tvOS)

#if TARGET_OS_TV
- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    // 键盘可见时优先聚焦到键盘区域
    if (_isVisible && _allKeys.count > 0) {
        return @[_allKeys[0]];
    }
    return @[];
}

- (BOOL)shouldUpdateFocusInContext:(UIFocusUpdateContext *)context {
    // 键盘可见时阻止焦点离开键盘
    if (_isVisible) {
        UIView *nextView = context.nextFocusedView;
        return [nextView isDescendantOfView:self];
    }
    return YES;
}
#endif

@end
```

**Step 3: 将文件添加到 Xcode 项目**

将 `KeyboardOverlayView.h` 和 `KeyboardOverlayView.m` 添加到 `Moonlight` 和 `Moonlight TV` 两个 target，放在 `Limelight/Input` group 下。

**Step 4: 验证编译**

Run: `xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add Limelight/Input/KeyboardOverlayView.h Limelight/Input/KeyboardOverlayView.m Moonlight.xcodeproj/project.pbxproj
git commit -m "添加 KeyboardOverlayView 虚拟键盘覆盖层

US QWERTY 全键盘布局（19列x6行）：
- ESC/F1-F12/数字行/QWERTY/控制行完整布局
- 修饰键 Toggle 状态（Shift/Ctrl/Alt/CapsLock）
- Shift 时显示符号标签，普通键按下后自动取消 Shift
- 半透明背景 + 底部滑入动画
- tvOS Focus Engine 支持（焦点锁定在键盘内）
- 按键通过 LiSendKeyboardEvent 发送到主机"
```

---

## Task 5: 集成到 StreamFrameViewController（Toast + 键盘管理）

**Files:**
- Modify: `Limelight/ViewControllers/StreamFrameViewController.h`
- Modify: `Limelight/ViewControllers/StreamFrameViewController.m`

**Step 1: 修改 StreamFrameViewController.h**

在 protocol 列表中添加 `ControllerSupportDelegate` 新增的方法（已在协议中声明，只需确认 ViewController 实现）。无需修改 .h 文件，因为 `StreamFrameViewController` 已经遵循 `ControllerSupportDelegate`。

**Step 2: 修改 StreamFrameViewController.m**

2a. 导入头文件：

```objc
// 在现有 import 之后添加
#import "KeyboardOverlayView.h"
```

2b. 在 `@implementation` 块的实例变量中添加：

```objc
@implementation StreamFrameViewController {
    // ... 现有变量 ...

    // 新增：鼠标模式和虚拟键盘
    KeyboardOverlayView *_keyboardOverlay;
    UILabel *_toastLabel;
    NSTimer *_toastTimer;
}
```

2c. 在 `viewDidLoad` 中，创建键盘覆盖层和 Toast 标签。在 `_streamView` 添加到 view 之后、`_stageLabel` 添加之前：

```objc
// === 新增：虚拟键盘覆盖层 ===
_keyboardOverlay = [[KeyboardOverlayView alloc] initWithFrame:self.view.bounds];
_keyboardOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
[self.view addSubview:_keyboardOverlay];

// === 新增：Toast 提示标签 ===
_toastLabel = [[UILabel alloc] init];
_toastLabel.textColor = [UIColor whiteColor];
_toastLabel.backgroundColor = [UIColor colorWithWhite:0 alpha:0.7];
_toastLabel.textAlignment = NSTextAlignmentCenter;
#if TARGET_OS_TV
_toastLabel.font = [UIFont systemFontOfSize:28];
#else
_toastLabel.font = [UIFont systemFontOfSize:14];
#endif
_toastLabel.layer.cornerRadius = 8;
_toastLabel.clipsToBounds = YES;
_toastLabel.alpha = 0;
_toastLabel.translatesAutoresizingMaskIntoConstraints = NO;
[self.view addSubview:_toastLabel];

[NSLayoutConstraint activateConstraints:@[
    [_toastLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
    [_toastLabel.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:20],
    [_toastLabel.widthAnchor constraintGreaterThanOrEqualToConstant:200],
    [_toastLabel.heightAnchor constraintEqualToConstant:40],
]];
```

2d. 实现 `ControllerSupportDelegate` 新增方法：

```objc
#pragma mark - 鼠标模式 Delegate

- (void)mouseModeDidChange:(BOOL)enabled {
    NSString *message = enabled ? @"Mouse Mode ON" : @"Gamepad Mode";
    [self showToast:message];

    if (!enabled) {
        // 退出鼠标模式时关闭键盘
        [_keyboardOverlay dismissAnimated:YES];
        [_controllerSupport.gamepadMouseHandler setKeyboardVisible:NO];
    }

#if TARGET_OS_TV
    [self setNeedsFocusUpdate];
#endif
}

- (void)requestToggleKeyboard {
    if (_keyboardOverlay.isVisible) {
        [_keyboardOverlay dismissAnimated:YES];
        [_controllerSupport.gamepadMouseHandler setKeyboardVisible:NO];
    } else {
        [_keyboardOverlay showAnimated:YES];
        [_controllerSupport.gamepadMouseHandler setKeyboardVisible:YES];
    }

#if TARGET_OS_TV
    [self setNeedsFocusUpdate];
#endif
}

#pragma mark - Toast 提示

- (void)showToast:(NSString *)message {
    // 添加内边距
    NSString *paddedMessage = [NSString stringWithFormat:@"  %@  ", message];
    _toastLabel.text = paddedMessage;

    [_toastTimer invalidate];

    [UIView animateWithDuration:0.3 animations:^{
        self->_toastLabel.alpha = 1;
    }];

    _toastTimer = [NSTimer scheduledTimerWithTimeInterval:2.0
                                                  target:self
                                                selector:@selector(hideToast)
                                                userInfo:nil
                                                 repeats:NO];
}

- (void)hideToast {
    [UIView animateWithDuration:0.5 animations:^{
        self->_toastLabel.alpha = 0;
    }];
    _toastTimer = nil;
}
```

2e. 在 tvOS 上添加 Menu 按键支持调出键盘。修改现有的 `controllerPauseButtonPressed:`：

```objc
#if TARGET_OS_TV
- (void)controllerPauseButtonPressed:(id)sender {
    // 如果在鼠标模式，Menu 单击切换虚拟键盘
    if (_controllerSupport.gamepadMouseHandler.mouseMode) {
        [self requestToggleKeyboard];
    }
}
#endif
```

2f. 在 `willMoveToParentViewController:` 的清理逻辑中：

```objc
if (parent == nil) {
    [_toastTimer invalidate];
    _toastTimer = nil;
    // ... 现有清理逻辑 ...
}
```

2g. tvOS 焦点管理支持（可选，仅 tvOS）：

```objc
#if TARGET_OS_TV
- (NSArray<id<UIFocusEnvironment>> *)preferredFocusEnvironments {
    if (_keyboardOverlay.isVisible) {
        return @[_keyboardOverlay];
    }
    return @[self.view];
}
#endif
```

**Step 3: 验证编译**

Run: `xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

Run: `xcodebuild -project Moonlight.xcodeproj -scheme "Moonlight TV" -destination 'platform=tvOS Simulator,name=Apple TV' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

**Step 4: Commit**

```bash
git add Limelight/ViewControllers/StreamFrameViewController.m
git commit -m "集成鼠标模式和虚拟键盘到 StreamFrameViewController

- 模式切换 Toast 提示（2 秒自动消失）
- Y 键或 tvOS Menu 键切换虚拟键盘显示
- 退出鼠标模式时自动关闭键盘
- tvOS 焦点管理：键盘可见时焦点锁定在键盘内"
```

---

## Task 6: 验证完整功能

**Step 1: 编译两个 target**

Run: `xcodebuild -project Moonlight.xcodeproj -scheme Moonlight -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

Run: `xcodebuild -project Moonlight.xcodeproj -scheme "Moonlight TV" -destination 'platform=tvOS Simulator,name=Apple TV' build 2>&1 | tail -10`
Expected: BUILD SUCCEEDED

**Step 2: 功能自测清单**

在设备上连接手柄进行测试：

- [ ] 正常手柄模式不受影响（LiSendMultiControllerEvent 正常发送）
- [ ] LB+RB 同时按下切换到鼠标模式，Toast 显示 "Mouse Mode ON"
- [ ] 鼠标模式下左摇杆控制光标移动（立方加速曲线）
- [ ] A 键模拟鼠标左键点击
- [ ] X 键模拟鼠标右键点击
- [ ] LT/RT 模拟备用左右键
- [ ] 右摇杆控制垂直/水平滚轮
- [ ] Y 键调出虚拟键盘
- [ ] 虚拟键盘导航和按键输入正常
- [ ] 修饰键 toggle 和视觉高亮正常
- [ ] B 键或 Y 键关闭虚拟键盘
- [ ] LB+RB 再次按下回到手柄模式，Toast 显示 "Gamepad Mode"
- [ ] Start+Select+L1+R1 退出组合键在任何模式下都有效
- [ ] tvOS 上 Menu 单击可切换虚拟键盘

**Step 3: 最终 Commit**

确认所有功能正常后，确保所有改动已提交。
