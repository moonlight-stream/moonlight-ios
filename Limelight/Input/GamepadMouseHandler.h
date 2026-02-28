//
//  GamepadMouseHandler.h
//  Moonlight
//
//  手柄模拟鼠标模式核心处理类
//  负责将手柄摇杆输入转换为鼠标移动、滚轮和按钮事件
//

#import <Foundation/Foundation.h>
#import "Controller.h"
#import "GamepadMouseConfig.h"

@protocol GamepadMouseDelegate <NSObject>

// 鼠标模式开关状态变化回调
- (void)mouseModeDidChange:(BOOL)enabled;

// 请求显示/隐藏虚拟键盘
- (void)requestToggleKeyboard;

@end

@interface GamepadMouseHandler : NSObject

/// 当前是否处于鼠标模式
@property (nonatomic, readonly) BOOL mouseMode;

/// 当前虚拟键盘是否可见
@property (nonatomic, readonly) BOOL keyboardVisible;

/// 委托对象，接收模式变化和键盘切换请求
@property (nonatomic, weak) id<GamepadMouseDelegate> delegate;

/// 使用指定委托初始化
/// @param delegate 接收事件回调的委托对象
- (instancetype)initWithDelegate:(id<GamepadMouseDelegate>)delegate;

/// 切换鼠标模式的开关状态
- (void)toggleMouseMode;

/// 通知虚拟键盘的显示状态（由外部调用设置）
/// @param visible 键盘是否可见
- (void)setKeyboardVisible:(BOOL)visible;

/// 处理手柄输入事件
/// @param controller 当前手柄控制器对象
/// @return YES 表示输入已被鼠标模式消费，不应继续传递
- (BOOL)handleGamepadInput:(Controller*)controller;

/// 检测是否应切换鼠标模式（LB+RB 组合键检测）
/// @param controller 当前手柄控制器对象
/// @return YES 表示检测到切换组合键
- (BOOL)shouldToggleMouseMode:(Controller*)controller;

/// 清理所有资源，停止定时器并重置状态
- (void)cleanup;

@end
