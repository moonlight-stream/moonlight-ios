//
//  HapticContext.m
//  Moonlight
//
//  Created by Cameron Gutman on 9/17/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#import "HapticContext.h"

@import CoreHaptics;
@import GameController;

@implementation HapticContext {
    GCControllerPlayerIndex _playerIndex;
    CHHapticEngine* _hapticEngine API_AVAILABLE(ios(13.0), tvos(14.0));
    id<CHHapticPatternPlayer> _hapticPlayer API_AVAILABLE(ios(13.0), tvos(14.0));
    BOOL _playing;
}

-(void)cleanup API_AVAILABLE(ios(14.0), tvos(14.0)) {
    if (_hapticPlayer != nil) {
        [_hapticPlayer cancelAndReturnError:nil];
        _hapticPlayer = nil;
    }
    if (_hapticEngine != nil) {
        [_hapticEngine stopWithCompletionHandler:nil];
        _hapticEngine = nil;
    }
}

-(void)setMotorAmplitude:(unsigned short)amplitude API_AVAILABLE(ios(14.0), tvos(14.0)) {
    NSError* error;

    // Check if the haptic engine died
    if (_hapticEngine == nil) {
        return;
    }
    
    // Stop the effect entirely if the amplitude is 0
    if (amplitude == 0) {
        if (_playing) {
            [_hapticPlayer stopAtTime:0 error:&error];
            _playing = NO;
        }
        
        return;
    }

    if (_hapticPlayer == nil) {
        // We must initialize the intensity to 1.0f because the dynamic parameters are multiplied by this value before being applied
        CHHapticEventParameter* intensityParameter = [[CHHapticEventParameter alloc] initWithParameterID:CHHapticEventParameterIDHapticIntensity value:1.0f];
        CHHapticEvent* hapticEvent = [[CHHapticEvent alloc] initWithEventType:CHHapticEventTypeHapticContinuous parameters:[NSArray arrayWithObject:intensityParameter] relativeTime:0 duration:GCHapticDurationInfinite];
        CHHapticPattern* hapticPattern = [[CHHapticPattern alloc] initWithEvents:[NSArray arrayWithObject:hapticEvent] parameters:[[NSArray alloc] init] error:&error];
        if (error != nil) {
            Log(LOG_W, @"Controller %d: Haptic pattern creation failed: %@", _playerIndex, error);
            return;
        }
        
        _hapticPlayer = [_hapticEngine createPlayerWithPattern:hapticPattern error:&error];
        if (error != nil) {
            Log(LOG_W, @"Controller %d: Haptic player creation failed: %@", _playerIndex, error);
            return;
        }
    }

    CHHapticDynamicParameter* intensityParameter = [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticIntensityControl value:amplitude / 65535.0f relativeTime:0];
    [_hapticPlayer sendParameters:[NSArray arrayWithObject:intensityParameter] atTime:CHHapticTimeImmediate error:&error];
    if (error != nil) {
        Log(LOG_W, @"Controller %d: Haptic player parameter update failed: %@", _playerIndex, error);
        return;
    }
    
    if (!_playing) {
        [_hapticPlayer startAtTime:0 error:&error];
        if (error != nil) {
            _hapticPlayer = nil;
            Log(LOG_W, @"Controller %d: Haptic playback start failed: %@", _playerIndex, error);
            return;
        }
        
        _playing = YES;
    }
}

-(id) initWithGamepad:(GCController*)gamepad locality:(GCHapticsLocality)locality API_AVAILABLE(ios(14.0), tvos(14.0)) {
    if (gamepad.haptics == nil) {
        Log(LOG_W, @"Controller %d does not support haptics", gamepad.playerIndex);
        return nil;
    }
    
    _playerIndex = gamepad.playerIndex;
    _hapticEngine = [gamepad.haptics createEngineWithLocality:locality];
    
    NSError* error;
    [_hapticEngine startAndReturnError:&error];
    if (error != nil) {
        Log(LOG_W, @"Controller %d: Haptic engine failed to start: %@", gamepad.playerIndex, error);
        return nil;
    }
    
    __weak typeof(self) weakSelf = self;
    _hapticEngine.stoppedHandler = ^(CHHapticEngineStoppedReason stoppedReason) {
        HapticContext* me = weakSelf;
        if (me == nil) {
            return;
        }
        
        Log(LOG_W, @"Controller %d: Haptic engine stopped: %p", me->_playerIndex, stoppedReason);
        me->_hapticPlayer = nil;
        me->_hapticEngine = nil;
        me->_playing = NO;
    };
    _hapticEngine.resetHandler = ^{
        HapticContext* me = weakSelf;
        if (me == nil) {
            return;
        }
        
        Log(LOG_W, @"Controller %d: Haptic engine reset", me->_playerIndex);
        me->_hapticPlayer = nil;
        me->_playing = NO;
        [me->_hapticEngine startAndReturnError:nil];
    };
    
    return self;
}

+(HapticContext*) createContextForHighFreqMotor:(GCController*)gamepad {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        return [[HapticContext alloc] initWithGamepad:gamepad locality:GCHapticsLocalityRightHandle];
    }
    else {
        return nil;
    }
}

+(HapticContext*) createContextForLowFreqMotor:(GCController*)gamepad {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        return [[HapticContext alloc] initWithGamepad:gamepad locality:GCHapticsLocalityLeftHandle];
    }
    else {
        return nil;
    }
}

@end
