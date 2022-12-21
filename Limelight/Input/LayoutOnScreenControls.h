//
//  LayoutOnScreenControls.h
//  Moonlight
//
//  Created by Long Le on 9/26/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OnScreenControls.h"
NS_ASSUME_NONNULL_BEGIN

@interface LayoutOnScreenControls : OnScreenControls

@property UIView* _view;
@property NSMutableArray *layoutChanges;
@property CALayer *layerCurrentlyBeingTouched;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig oscLevel:(int)oscLevel;
- (CALayer*)buttonLayerFromName: (NSString*)name;
- (BOOL)isLayer:(CALayer*)layer hoveringOverButton: (UIButton*)button;
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;
@end

NS_ASSUME_NONNULL_END
