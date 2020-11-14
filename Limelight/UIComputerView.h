//
//  UIComputerView.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/22/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TemporaryHost.h"

@protocol HostCallback <NSObject>

- (void) hostClicked:(TemporaryHost*)host view:(UIView*)view;
- (void) hostLongClicked:(TemporaryHost*)host view:(UIView*)view;
- (void) addHostClicked;

@end

#if !TARGET_OS_TV
@interface UIComputerView : UIButton <UIContextMenuInteractionDelegate>
#else
@interface UIComputerView : UIButton
#endif

- (id) initWithComputer:(TemporaryHost*)host andCallback:(id<HostCallback>)callback;
- (id) initForAddWithCallback:(id<HostCallback>)callback;

@end
