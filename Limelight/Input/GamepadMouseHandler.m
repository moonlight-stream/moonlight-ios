//
//  GamepadMouseHandler.m
//  Moonlight
//
//  手柄模拟鼠标模式核心实现
//  将手柄左摇杆映射为鼠标移动（立方加速曲线），右摇杆映射为滚轮，
//  按钮映射为鼠标左右键点击，并支持 LB+RB 组合键切换模式。
//

#import "GamepadMouseHandler.h"
#include "Limelight.h"

@implementation GamepadMouseHandler {
    // 配置参数
    GamepadMouseConfig _config;

    // 鼠标移动的浮点累积器（保留小数部分以保证精度）
    float _accumulatedMouseX;
    float _accumulatedMouseY;

    // 滚轮的浮点累积器
    float _accumulatedScrollX;
    float _accumulatedScrollY;

    // 按钮边缘检测的前一帧状态
    BOOL _aPressed;           // A 键 → 鼠标左键
    BOOL _xPressed;           // X 键 → 鼠标右键
    BOOL _yPressed;           // Y 键 → 切换虚拟键盘
    BOOL _ltPressed;          // LT 扳机 → 鼠标左键
    BOOL _rtPressed;          // RT 扳机 → 鼠标右键

    // 模式切换防抖标志（避免 LB+RB 持续触发）
    BOOL _toggleCooldown;

    // 轮询定时器（定期采集摇杆状态并发送鼠标事件）
    NSTimer *_pollTimer;

    // 缓存当前手柄引用，供定时器回调读取最新状态
    __weak Controller *_currentController;
}

#pragma mark - 初始化

- (instancetype)initWithDelegate:(id<GamepadMouseDelegate>)delegate {
    self = [super init];
    if (self) {
        _delegate = delegate;
        _config = GamepadMouseConfigDefault();
        _mouseMode = NO;
        _keyboardVisible = NO;
        [self resetAllState];
    }
    return self;
}

#pragma mark - 模式切换

- (void)toggleMouseMode {
    @synchronized (self) {
        _mouseMode = !_mouseMode;

        if (_mouseMode) {
            // 进入鼠标模式：启动轮询定时器
            [self startPollTimer];
        } else {
            // 退出鼠标模式：停止定时器，释放所有已按下的鼠标按钮
            [self stopPollTimer];
            // 注意顺序：releaseAllButtons 必须在 resetAllState 之前调用，
            // 因为 releaseAllButtons 依赖 _aPressed/_xPressed/_ltPressed/_rtPressed
            // 状态来判断哪些按钮需要释放，resetAllState 会清除这些标志。
            [self releaseAllButtons];
        }

        // 重置累积器和按钮状态
        [self resetAllState];
    }

    // 在主线程通知委托
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf) {
            [strongSelf.delegate mouseModeDidChange:strongSelf.mouseMode];
        }
    });
}

- (void)setKeyboardVisible:(BOOL)visible {
    @synchronized (self) {
        _keyboardVisible = visible;
    }
}

#pragma mark - LB+RB 组合键检测

- (BOOL)shouldToggleMouseMode:(Controller*)controller {
    @synchronized (self) {
        int flags = controller.lastButtonFlags;
        BOOL lbPressed = (flags & LB_FLAG) != 0;
        BOOL rbPressed = (flags & RB_FLAG) != 0;

        // 检查是否只按了 LB+RB，没有其他按钮
        int otherButtonMask = ~(LB_FLAG | RB_FLAG);
        BOOL noOtherButtons = (flags & otherButtonMask) == 0;

        // 检查摇杆是否在中立位置（绝对值 < 3000）
        BOOL sticksNeutral = (abs(controller.lastLeftStickX) < 3000) &&
                             (abs(controller.lastLeftStickY) < 3000) &&
                             (abs(controller.lastRightStickX) < 3000) &&
                             (abs(controller.lastRightStickY) < 3000);

        // 检查扳机是否在中立位置（< 128）
        BOOL triggersNeutral = (controller.lastLeftTrigger < 128) &&
                               (controller.lastRightTrigger < 128);

        if (lbPressed && rbPressed && noOtherButtons && sticksNeutral && triggersNeutral) {
            if (!_toggleCooldown) {
                // 首次检测到组合键，设置防抖标志并触发切换
                _toggleCooldown = YES;
                return YES;
            }
        } else {
            // 组合键释放后重置防抖标志，允许下次触发
            _toggleCooldown = NO;
        }

        return NO;
    }
}

#pragma mark - 手柄输入处理入口

- (BOOL)handleGamepadInput:(Controller*)controller {
    @synchronized (self) {
        if (!_mouseMode) {
            return NO;
        }

        // 缓存手柄引用，供定时器回调使用
        _currentController = controller;

        // 虚拟键盘可见时，消费输入但不处理按钮事件
        // （避免误触导致鼠标点击干扰键盘操作）
        if (_keyboardVisible) {
            return YES;
        }

        // 处理按钮事件（边缘检测）
        [self handleButtonEvents:controller];

        return YES;
    }
}

#pragma mark - 按钮事件处理（边缘检测）

/// 通过比较前后帧的按钮状态实现边缘检测，
/// 只在按下/释放瞬间发送一次事件，避免持续触发。
- (void)handleButtonEvents:(Controller*)controller {
    int flags = controller.lastButtonFlags;

    // A 键 → 鼠标左键
    BOOL aCurrentlyPressed = (flags & A_FLAG) != 0;
    if (aCurrentlyPressed != _aPressed) {
        _aPressed = aCurrentlyPressed;
        LiSendMouseButtonEvent(
            aCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_LEFT
        );
    }

    // X 键 → 鼠标右键
    BOOL xCurrentlyPressed = (flags & X_FLAG) != 0;
    if (xCurrentlyPressed != _xPressed) {
        _xPressed = xCurrentlyPressed;
        LiSendMouseButtonEvent(
            xCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_RIGHT
        );
    }

    // Y 键 → 切换虚拟键盘（仅在按下边缘触发）
    BOOL yCurrentlyPressed = (flags & Y_FLAG) != 0;
    if (yCurrentlyPressed && !_yPressed) {
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf) {
                [strongSelf.delegate requestToggleKeyboard];
            }
        });
    }
    _yPressed = yCurrentlyPressed;

    // LT 扳机 → 鼠标左键（阈值 128）
    BOOL ltCurrentlyPressed = (controller.lastLeftTrigger >= 128);
    if (ltCurrentlyPressed != _ltPressed) {
        _ltPressed = ltCurrentlyPressed;
        LiSendMouseButtonEvent(
            ltCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_LEFT
        );
    }

    // RT 扳机 → 鼠标右键（阈值 128）
    BOOL rtCurrentlyPressed = (controller.lastRightTrigger >= 128);
    if (rtCurrentlyPressed != _rtPressed) {
        _rtPressed = rtCurrentlyPressed;
        LiSendMouseButtonEvent(
            rtCurrentlyPressed ? BUTTON_ACTION_PRESS : BUTTON_ACTION_RELEASE,
            BUTTON_RIGHT
        );
    }
}

#pragma mark - 鼠标移动轮询

/// 定时器回调：读取摇杆状态，计算鼠标移动和滚轮事件
- (void)pollMouseMovement {
    @synchronized (self) {
        // 虚拟键盘可见时暂停鼠标移动
        if (_keyboardVisible) {
            return;
        }

        Controller *controller = _currentController;
        if (controller == nil) {
            return;
        }

        // === 左摇杆 → 鼠标移动 ===
        [self processMouseMovement:controller];

        // === 右摇杆 → 滚轮 ===
        [self processScrollWheel:controller];
    }
}

/// 处理左摇杆到鼠标移动的转换
/// 使用立方加速曲线：小幅度移动精确，大幅度移动快速
- (void)processMouseMovement:(Controller*)controller {
    // 归一化摇杆值到 -1.0 ~ 1.0 范围
    float normalizedX = controller.lastLeftStickX / 32766.0f;
    float normalizedY = controller.lastLeftStickY / 32766.0f;

    // 死区过滤：消除摇杆零点漂移
    if (fabsf(normalizedX) < _config.deadzone) {
        normalizedX = 0.0f;
    }
    if (fabsf(normalizedY) < _config.deadzone) {
        normalizedY = 0.0f;
    }

    // 没有有效输入时不发送事件
    if (normalizedX == 0.0f && normalizedY == 0.0f) {
        return;
    }

    // 立方加速曲线：先缩放再立方
    // scaledX = normalizedX * (sensitivity / 4.0)
    // deltaX = scaledX^3（立方保留符号）
    float sensitivityMultiplier = _config.sensitivity / 4.0f;

    float scaledX = normalizedX * sensitivityMultiplier;
    float deltaX = scaledX * scaledX * scaledX;

    // Y 轴反转：摇杆向上（正值）对应鼠标向上（负值）
    float scaledY = -normalizedY * sensitivityMultiplier;
    float deltaY = scaledY * scaledY * scaledY;

    // 浮点累积：保留小数部分，只发送整数部分
    _accumulatedMouseX += deltaX;
    _accumulatedMouseY += deltaY;

    short sendX = (short)_accumulatedMouseX;
    short sendY = (short)_accumulatedMouseY;

    if (sendX != 0 || sendY != 0) {
        LiSendMouseMoveEvent(sendX, sendY);

        // 保留小数余量，确保微小移动不丢失
        _accumulatedMouseX -= sendX;
        _accumulatedMouseY -= sendY;
    }
}

/// 处理右摇杆到滚轮的转换（线性映射）
- (void)processScrollWheel:(Controller*)controller {
    // 归一化右摇杆值
    float normalizedX = controller.lastRightStickX / 32766.0f;
    float normalizedY = controller.lastRightStickY / 32766.0f;

    // 死区过滤
    if (fabsf(normalizedX) < _config.deadzone) {
        normalizedX = 0.0f;
    }
    if (fabsf(normalizedY) < _config.deadzone) {
        normalizedY = 0.0f;
    }

    // 垂直滚轮（右摇杆 Y 轴）
    if (normalizedY != 0.0f) {
        // 线性映射，应用滚轮速度乘数
        float scrollDeltaY = normalizedY * _config.scrollSpeed;
        _accumulatedScrollY += scrollDeltaY;

        short sendScrollY = (short)_accumulatedScrollY;
        if (sendScrollY != 0) {
            LiSendHighResScrollEvent(sendScrollY);
            _accumulatedScrollY -= sendScrollY;
        }
    }

    // 水平滚轮（右摇杆 X 轴）
    if (normalizedX != 0.0f) {
        float scrollDeltaX = normalizedX * _config.scrollSpeed;
        _accumulatedScrollX += scrollDeltaX;

        short sendScrollX = (short)_accumulatedScrollX;
        if (sendScrollX != 0) {
            LiSendHighResHScrollEvent(sendScrollX);
            _accumulatedScrollX -= sendScrollX;
        }
    }
}

#pragma mark - 定时器管理

- (void)startPollTimer {
    [self stopPollTimer];

    // 必须在主线程创建并加入 mainRunLoop，因为 toggleMouseMode 可能在
    // GCController 回调的后台队列上调用，后台队列没有活跃的 NSRunLoop，
    // 定时器无法触发。使用 block-based API 避免 target:selector: 的循环引用。
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.mouseMode) return;

        strongSelf->_pollTimer = [NSTimer timerWithTimeInterval:strongSelf->_config.pollInterval
                                                        repeats:YES
                                                          block:^(NSTimer *timer) {
            __strong typeof(weakSelf) strongSelf2 = weakSelf;
            if (strongSelf2) {
                [strongSelf2 pollMouseMovement];
            } else {
                [timer invalidate];
            }
        }];
        // 加入 CommonModes 确保在滚动等场景下仍能触发
        [[NSRunLoop mainRunLoop] addTimer:strongSelf->_pollTimer forMode:NSRunLoopCommonModes];
    });
}

- (void)stopPollTimer {
    [_pollTimer invalidate];
    _pollTimer = nil;
}

#pragma mark - 状态重置

/// 重置所有累积器和按钮状态
- (void)resetAllState {
    @synchronized (self) {
        _accumulatedMouseX = 0.0f;
        _accumulatedMouseY = 0.0f;
        _accumulatedScrollX = 0.0f;
        _accumulatedScrollY = 0.0f;

        _aPressed = NO;
        _xPressed = NO;
        _yPressed = NO;
        _ltPressed = NO;
        _rtPressed = NO;

        _toggleCooldown = NO;
    }
}

/// 释放所有当前已按下的鼠标按钮，防止鼠标键卡住
- (void)releaseAllButtons {
    @synchronized (self) {
        if (_aPressed) {
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
            _aPressed = NO;
        }
        if (_xPressed) {
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
            _xPressed = NO;
        }
        if (_ltPressed) {
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
            _ltPressed = NO;
        }
        if (_rtPressed) {
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
            _rtPressed = NO;
        }
    }
}

#pragma mark - 资源清理

- (void)cleanup {
    @synchronized (self) {
        [self stopPollTimer];

        // 退出前释放所有按钮，避免远端鼠标键卡住
        if (_mouseMode) {
            [self releaseAllButtons];
        }

        [self resetAllState];
        _mouseMode = NO;
        _keyboardVisible = NO;
        _currentController = nil;
        _delegate = nil;
    }
}

- (void)dealloc {
    [self cleanup];
}

@end
