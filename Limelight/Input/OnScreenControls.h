//
//  OnScreenControls.h
//  Moonlight
//
//  Created by Diego Waxemberg on 12/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ControllerSupport.h"
#import "OSCProfile.h"

@class ControllerSupport;
@class StreamConfiguration;

@interface OnScreenControls : NSObject

typedef NS_ENUM(NSInteger, OnScreenControlsLevel) {
    OnScreenControlsLevelOff,
    OnScreenControlsLevelAuto,
    OnScreenControlsLevelSimple,
    OnScreenControlsLevelFull,
    OnScreenControlsCustom,
    
    // Internal levels selected by ControllerSupport
    OnScreenControlsLevelAutoGCGamepad,
    OnScreenControlsLevelAutoGCExtendedGamepad,
    OnScreenControlsLevelAutoGCExtendedGamepadWithStickButtons
};

@property CALayer* _aButton;
@property CALayer* _bButton;
@property CALayer* _xButton;
@property CALayer* _yButton;
@property CALayer* _startButton;
@property CALayer* _selectButton;
@property CALayer* _r1Button;
@property CALayer* _r2Button;
@property CALayer* _r3Button;
@property CALayer* _l1Button;
@property CALayer* _l2Button;
@property CALayer* _l3Button;
@property CALayer* _upButton;
@property CALayer* _downButton;
@property CALayer* _leftButton;
@property CALayer* _rightButton;
@property CALayer* _leftStickBackground;
@property CALayer* _leftStick;
@property CALayer* _rightStickBackground;
@property CALayer* _rightStick;
@property float D_PAD_CENTER_X;
@property float D_PAD_CENTER_Y;
@property OnScreenControlsLevel _level;
@property NSMutableArray *OSCButtonLayers;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig;
- (BOOL) handleTouchDownEvent:(NSSet*)touches;
- (BOOL) handleTouchUpEvent:(NSSet*)touches;
- (BOOL) handleTouchMovedEvent:(NSSet*)touches;
- (void) setLevel:(OnScreenControlsLevel)level;
- (OnScreenControlsLevel) getLevel;
- (void) show;
- (void) setupComplexControls;
- (void) drawButtons;
- (void) layoutOSC;
- (void) updateControls;

@end
