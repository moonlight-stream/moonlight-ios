//
//  ConnectionCallbacks.h
//  Moonlight
//
//  Created by Cameron Gutman on 11/1/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

@protocol ConnectionCallbacks <NSObject>

- (void) connectionStarted;
- (void) connectionTerminated:(int)errorCode;
- (void) stageStarting:(const char*)stageName;
- (void) stageComplete:(const char*)stageName;
- (void) stageFailed:(const char*)stageName withError:(int)errorCode portTestFlags:(int)portTestFlags;
- (void) launchFailed:(NSString*)message;
- (void) rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor;
- (void) connectionStatusUpdate:(int)status;
- (void) setHdrMode:(bool)enabled;
- (void) rumbleTriggers:(uint16_t)controllerNumber leftTrigger:(uint16_t)leftTrigger rightTrigger:(uint16_t)rightTrigger;
- (void) setMotionEventState:(uint16_t)controllerNumber motionType:(uint8_t)motionType reportRateHz:(uint16_t)reportRateHz;
- (void) videoContentShown;

@end
