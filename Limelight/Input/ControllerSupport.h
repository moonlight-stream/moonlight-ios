//
//  ControllerSupport.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "StreamConfiguration.h"
#import "Controller.h"

@class OnScreenControls;

@protocol ControllerSupportDelegate <NSObject>

- (void) gamepadPresenceChanged;
- (void) mousePresenceChanged;
- (void) streamExitRequested;

@end

@interface ControllerSupport : NSObject

-(id) initWithConfig:(StreamConfiguration*)streamConfig delegate:(id<ControllerSupportDelegate>)delegate;

-(void) initAutoOnScreenControlMode:(OnScreenControls*)osc;
-(void) cleanup;
-(Controller*) getOscController;

-(void) updateLeftStick:(Controller*)controller x:(short)x y:(short)y;
-(void) updateRightStick:(Controller*)controller x:(short)x y:(short)y;

-(void) updateLeftTrigger:(Controller*)controller left:(unsigned char)left;
-(void) updateRightTrigger:(Controller*)controller right:(unsigned char)right;
-(void) updateTriggers:(Controller*)controller left:(unsigned char)left right:(unsigned char)right;

-(void) updateButtonFlags:(Controller*)controller flags:(int)flags;
-(void) setButtonFlag:(Controller*)controller flags:(int)flags;
-(void) clearButtonFlag:(Controller*)controller flags:(int)flags;

-(void) updateFinished:(Controller*)controller;

-(void) rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor;

+(int) getConnectedGamepadMask:(StreamConfiguration*)streamConfig;

-(NSUInteger) getConnectedGamepadCount;

@end
