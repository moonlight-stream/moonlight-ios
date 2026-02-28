//
//  KeyboardOverlayView.h
//  Moonlight
//
//  虚拟键盘覆盖层，支持 iOS 和 tvOS。
//  在鼠标模式下按手柄 Y 键时显示，提供完整的 US QWERTY 键盘布局，
//  通过 Limelight 协议向远程主机发送按键事件。
//

#import <UIKit/UIKit.h>

@interface KeyboardOverlayView : UIView

/// 键盘覆盖层当前是否可见
@property (nonatomic, readonly) BOOL isVisible;

/// 显示键盘覆盖层
/// @param animated 是否使用动画（从底部滑入 + 淡入）
- (void)showAnimated:(BOOL)animated;

/// 隐藏键盘覆盖层
/// @param animated 是否使用动画（向下滑出 + 淡出）
- (void)dismissAnimated:(BOOL)animated;

@end
