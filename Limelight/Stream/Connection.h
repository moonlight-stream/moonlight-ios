//
//  Connection.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "VideoDecoderRenderer.h"
#import "StreamConfiguration.h"

#define CONN_TEST_SERVER "ios.conntest.moonlight-stream.org"

typedef struct {
    CFTimeInterval startTime;
    CFTimeInterval endTime;
    int totalFrames;
    int receivedFrames;
    int networkDroppedFrames;
} video_stats_t;

@protocol ConnectionCallbacks <NSObject>

- (void) connectionStarted;
- (void) connectionTerminated:(int)errorCode;
- (void) stageStarting:(const char*)stageName;
- (void) stageComplete:(const char*)stageName;
- (void) stageFailed:(const char*)stageName withError:(int)errorCode portTestFlags:(int)portTestFlags;
- (void) launchFailed:(NSString*)message;
- (void) rumble:(unsigned short)controllerNumber lowFreqMotor:(unsigned short)lowFreqMotor highFreqMotor:(unsigned short)highFreqMotor;
- (void) connectionStatusUpdate:(int)status;

@end

@interface Connection : NSOperation <NSStreamDelegate>

-(id) initWithConfig:(StreamConfiguration*)config renderer:(VideoDecoderRenderer*)myRenderer connectionCallbacks:(id<ConnectionCallbacks>)callbacks;
-(void) terminate;
-(void) main;
-(BOOL) getVideoStats:(video_stats_t*)stats;
-(NSString*) getActiveCodecName;

@end
