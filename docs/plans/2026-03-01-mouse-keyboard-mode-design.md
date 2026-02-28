# 手柄模拟鼠标与键盘模式设计文档

## 概述

为 Moonlight iOS/tvOS 增加手柄模拟鼠标和键盘模式，参考 Xbox 版本的实现。用户可以通过手柄组合键切换到鼠标模式，用摇杆控制光标、按键模拟点击，并可调出虚拟键盘进行文字输入。

## 需求

| 项目 | 决定 |
|------|------|
| 核心功能 | 手柄模拟鼠标模式（摇杆控制光标、按键模拟点击） |
| 模式切换 | 组合键 LB+RB 同时按 |
| 按键映射 | 左摇杆=鼠标移动，A=左键，X=右键，右摇杆=滚轮，LT/RT=备用左右键 |
| 屏幕键盘 | 鼠标模式下按 Y 调出/隐藏，tvOS 额外支持 Menu 单击 |
| 灵敏度 | 固定值，先跑通流程 |
| 视觉反馈 | 模式切换时 Toast 提示 |
| 平台支持 | iOS + tvOS，参数差异化 |

## 架构：独立 GamepadMouseHandler 类（方案 A）

### 核心思路

创建独立的 `GamepadMouseHandler` 类，在 `ControllerSupport` 中拦截手柄输入。当鼠标模式激活时，将手柄事件转发给 `GamepadMouseHandler` 处理，而不是发送 `LiSendMultiControllerEvent`。

### 架构图

```
ControllerSupport (手柄输入入口)
    ├─ 普通模式 → LiSendMultiControllerEvent() (现有流程)
    └─ 鼠标模式 → GamepadMouseHandler
                    ├─ 左摇杆 → LiSendMouseMoveEvent()
                    ├─ A/LT → LiSendMouseButtonEvent(LEFT)
                    ├─ X/RT → LiSendMouseButtonEvent(RIGHT)
                    ├─ 右摇杆 → LiSendScrollEvent()
                    └─ Y → 切换屏幕键盘
```

### 集成点

在 `ControllerSupport.updateFinished:` 中拦截：

```objc
-(void) updateFinished:(Controller*)controller {
    // 退出组合键始终优先
    if (controller.lastButtonFlags == (PLAY_FLAG | BACK_FLAG | LB_FLAG | RB_FLAG)) {
        // 现有退出逻辑...
    }

    // 检测 LB+RB 组合键切换鼠标模式
    if ([self shouldToggleMouseMode:controller]) {
        [_gamepadMouseHandler toggleMouseMode];
        return;
    }

    // 鼠标模式下，交给 handler 处理
    if ([_gamepadMouseHandler handleGamepadInput:controller]) {
        return;  // 输入已被消费，不发送 LiSendMultiControllerEvent
    }

    // 正常手柄模式，执行现有逻辑...
    LiSendMultiControllerEvent(...);
}
```

## 平台差异化策略

### 平台特征对比

| 维度 | iOS (iPhone/iPad) | tvOS (Apple TV) |
|------|-------------------|-----------------|
| 电源 | 电池供电，需省电 | 常供电，无限制 |
| 使用场景 | 已有触摸屏可替代鼠标 | 手柄是主要输入设备，更刚需 |
| 屏幕距离 | 近距离，精细操作 | 远距离，客厅大屏 |
| 性能预算 | 保守 | 充裕 |

### 平台参数

```objc
typedef struct {
    NSTimeInterval pollInterval;  // 鼠标移动采样间隔
    float sensitivity;            // 灵敏度乘数
    float deadzone;               // 摇杆死区
    float scrollSpeed;            // 滚轮速度
} GamepadMouseConfig;
```

| 参数 | iOS | tvOS |
|------|-----|------|
| pollInterval | 1/120s (120Hz) | 1/240s (240Hz) |
| sensitivity | 3.0 | 4.0 |
| deadzone | 0.1 | 0.1 |
| scrollSpeed | 1.5 | 2.0 |

## 输入映射

### 按键映射表

| 手柄输入 | 鼠标模式动作 | Limelight API |
|---------|-------------|--------------|
| 左摇杆 | 鼠标移动 | `LiSendMouseMoveEvent(deltaX, deltaY)` |
| A 键 | 鼠标左键 | `LiSendMouseButtonEvent(BUTTON_ACTION_*, BUTTON_LEFT)` |
| X 键 | 鼠标右键 | `LiSendMouseButtonEvent(BUTTON_ACTION_*, BUTTON_RIGHT)` |
| LT (左扳机) | 备用左键 | `LiSendMouseButtonEvent(BUTTON_ACTION_*, BUTTON_LEFT)` |
| RT (右扳机) | 备用右键 | `LiSendMouseButtonEvent(BUTTON_ACTION_*, BUTTON_RIGHT)` |
| 右摇杆 Y轴 | 垂直滚轮 | `LiSendHighResScrollEvent(delta)` |
| 右摇杆 X轴 | 水平滚轮 | `LiSendHighResHScrollEvent(delta)` |
| Y 键 | 调出/隐藏屏幕键盘 | 通过 delegate 通知 |
| LB+RB 同时按 | 切换模式 | 内部状态切换 |

### 摇杆到鼠标移动算法

- 死区过滤：0.1
- 立方加速曲线：`pow(x * multiplier, 3)` — 低偏转精确，高偏转快速
- 浮点累积：避免小偏转截断导致鼠标不动
- 定时器轮询：iOS 120Hz / tvOS 240Hz

### LB+RB 切换检测

- 仅在 LB+RB 同时按下且无其他按键时触发
- 防抖机制：设置 cooldown 标志，松开后重置

## 虚拟键盘覆盖层

### 布局

19列 x 6行网格，与 Xbox 版一致：

- Row 0: ESC, F1-F12
- Row 1: ` 1 2 3 ... 0 - = [Backspace]
- Row 2: [Tab] Q W E R T Y ... [Delete]
- Row 3: [CapsLock] A S D F G ... [Enter]
- Row 4: [Shift] Z X C V B N M ... [Shift] [↑]
- Row 5: [Ctrl] [Win] [Alt] [   Space   ] [Alt] [Ctrl] [←][↓][→]

第一版只支持标准 US QWERTY 布局，国际化布局作为后续迭代。

### 触发方式

| 平台 | 触发方式 |
|------|---------|
| iOS | 鼠标模式下按 Y 键 |
| tvOS | 鼠标模式下按 Y 键 或 Menu 单击 |

### 导航方案

使用 tvOS 原生焦点引擎（Focus Engine）：

- 每个按键是 `UIButton`，天然支持焦点
- 焦点引擎自动处理 Siri Remote 和手柄 D-pad 网格导航
- 变宽按键焦点引擎自动处理
- `shouldUpdateFocusInContext:` 防止焦点逃逸
- iOS 上同样使用此方案，保持一致性

### 键盘显示时的输入状态

键盘显示时 `GamepadMouseHandler` 暂停摇杆鼠标移动，将控制权交给焦点引擎：

- D-pad → 焦点导航
- A 键 → 按下当前按键
- B 键 → 关闭键盘
- 摇杆 → 暂停鼠标移动

### 按键按下流程

```
用户按 A 选中按键 → 查找按键 VK code →
读取修饰键状态 (Shift/Ctrl/Alt) →
LiSendKeyboardEvent(vkCode, KEY_ACTION_DOWN, modifiers) →
延迟后 LiSendKeyboardEvent(vkCode, KEY_ACTION_UP, modifiers)
```

复用现有 `KeyboardSupport` 的 VK code 映射表。

### 视觉设计

- 半透明黑色背景（alpha: 0.5），游戏画面仍可见
- 按键：深灰色圆角矩形，白色文字
- 焦点状态：放大 1.1x + 浅色高亮
- 修饰键激活状态：高亮颜色标记

## 状态机

```
                    ┌──────────────┐
                    │  手柄模式     │  (默认)
                    │  正常发送     │
                    │  Controller   │
                    └──────┬───────┘
                           │ LB+RB
                           ▼
                    ┌──────────────┐
                    │  鼠标模式     │
                    │  摇杆→鼠标   │
                    │  A→左键      │
                    │  X→右键      │
                    └──┬───────┬───┘
                       │       │ LB+RB → 回到手柄模式
                    Y键│       │
                       ▼       │
                    ┌──────────────┐
                    │  键盘覆盖层   │
                    │  D-pad→导航  │
                    │  A→按键      │
                    │  B→关闭键盘  │
                    └──────────────┘
```

退出组合键 `Start+Select+L1+R1` 在任何模式下都优先于鼠标模式检测。

## 模式切换提示

屏幕顶部居中 Toast 提示，2 秒后自动消失：

- 开启鼠标模式：「鼠标模式已开启」
- 恢复手柄模式：「手柄模式已恢复」

通过 `GamepadMouseDelegate.mouseModeDidChange:` 回调触发，在 `StreamFrameViewController` 中用 `UILabel` + `UIView.animate` 淡入淡出实现。

## 文件清单

### 新增文件

| 文件 | 用途 |
|------|------|
| `GamepadMouseHandler.h/.m` | 手柄模拟鼠标核心逻辑 |
| `GamepadMouseConfig.h` | 平台差异化参数（纯 C 结构体） |
| `KeyboardOverlayView.h/.m` | 虚拟键盘覆盖层 |

### 修改文件

| 文件 | 修改内容 |
|------|---------|
| `ControllerSupport.h/.m` | 持有 `GamepadMouseHandler`，在 `updateFinished:` 中拦截分发 |
| `StreamFrameViewController.m` | 实现 `GamepadMouseDelegate`，管理 Toast 和键盘覆盖层 |
| `StreamView.m` | tvOS 下键盘覆盖层的焦点管理配合 |
