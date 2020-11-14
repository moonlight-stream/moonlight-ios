//
//  UIAppView.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/22/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TemporaryApp.h"

@protocol AppCallback <NSObject>

- (void) appClicked:(TemporaryApp*)app view:(UIView*)view;
- (void) appLongClicked:(TemporaryApp*)app view:(UIView*)view;

@end

#if !TARGET_OS_TV
@interface UIAppView : UIButton <UIContextMenuInteractionDelegate>
#else
@interface UIAppView : UIButton
#endif

- (id) initWithApp:(TemporaryApp*)app cache:(NSCache*)cache andCallback:(id<AppCallback>)callback;
- (void) updateAppImage;

@end
