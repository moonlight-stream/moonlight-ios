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

/**
 This object is a subclass on 'OnScreenControls' and adds additional properties and functions which allow the user to drag and drop each of the 19 on screen controller buttons in order to change their positions on screen. The object is used in the 'LayoutOnScreenControlsViewController' thus allowing the user to drag, drop, hide, unhide, on screen controller buttons.
 Note that this is in contrast to the game stream view which displays an 'OnScreenControls' object on screen that allows the app to register taps on each button as controller input. It does not (and naturally should not) allow the user to move the buttons around the screen.
 */
@interface LayoutOnScreenControls : OnScreenControls

@property UIView* _view;
@property NSMutableArray *layoutChanges;
@property CALayer *layerCurrentlyBeingTouched;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport
       streamConfig:(StreamConfiguration*)streamConfig oscLevel:(int)oscLevel;

- (CALayer*) buttonLayerFromName:(NSString*)name;
- (BOOL) isLayer:(CALayer*)layer hoveringOverButton:(UIButton*)button;

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event;
- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event;
- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event;

@end

NS_ASSUME_NONNULL_END
