//
//  HapticContext.h
//  Moonlight
//
//  Created by Cameron Gutman on 9/17/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

@import CoreHaptics;
@import GameController;

@interface HapticContext : NSObject

-(void)setMotorAmplitude:(unsigned short)amplitude;
-(void)cleanup;

+(HapticContext*) createContextForHighFreqMotor:(GCController*)gamepad;
+(HapticContext*) createContextForLowFreqMotor:(GCController*)gamepad;

@end
