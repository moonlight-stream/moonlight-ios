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

-(NSString*) hapticTargetDescription {
    if (_playerIndex == GCControllerPlayerIndexUnset) {
        return @"Device haptics";
    }

    return [NSString stringWithFormat:@"Controller %ld", (long)_playerIndex];
}

-(void)cleanup API_AVAILABLE(ios(13.0), tvos(14.0)) {
    if (_hapticPlayer != nil) {
        [_hapticPlayer cancelAndReturnError:nil];
        _hapticPlayer = nil;
    }
    if (_hapticEngine != nil) {
        [_hapticEngine stopWithCompletionHandler:nil];
        _hapticEngine = nil;
    }
}

-(void)setMotorAmplitude:(unsigned short)amplitude API_AVAILABLE(ios(13.0), tvos(14.0)) {
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
            Log(LOG_W, @"%@: Haptic pattern creation failed: %@", [self hapticTargetDescription], error);
            return;
        }
        
        _hapticPlayer = [_hapticEngine createPlayerWithPattern:hapticPattern error:&error];
        if (error != nil) {
            Log(LOG_W, @"%@: Haptic player creation failed: %@", [self hapticTargetDescription], error);
            return;
        }
    }

    CHHapticDynamicParameter* intensityParameter = [[CHHapticDynamicParameter alloc] initWithParameterID:CHHapticDynamicParameterIDHapticIntensityControl value:amplitude / 65535.0f relativeTime:0];
    [_hapticPlayer sendParameters:[NSArray arrayWithObject:intensityParameter] atTime:CHHapticTimeImmediate error:&error];
    if (error != nil) {
        Log(LOG_W, @"%@: Haptic player parameter update failed: %@", [self hapticTargetDescription], error);
        return;
    }
    
    if (!_playing) {
        [_hapticPlayer startAtTime:0 error:&error];
        if (error != nil) {
            _hapticPlayer = nil;
            Log(LOG_W, @"%@: Haptic playback start failed: %@", [self hapticTargetDescription], error);
            return;
        }
        
        _playing = YES;
    }
}

-(id) initWithHapticEngine:(CHHapticEngine*)hapticEngine playerIndex:(GCControllerPlayerIndex)playerIndex API_AVAILABLE(ios(13.0), tvos(14.0)) {
    self = [super init];
    if (self == nil || hapticEngine == nil) {
        return nil;
    }

    _playerIndex = playerIndex;
    _hapticEngine = hapticEngine;

#if !TARGET_OS_TV
    if (_playerIndex == GCControllerPlayerIndexUnset) {
        _hapticEngine.playsHapticsOnly = YES;
    }
#endif
    
    NSError* error;
    [_hapticEngine startAndReturnError:&error];
    if (error != nil) {
        Log(LOG_W, @"%@: Haptic engine failed to start: %@", [self hapticTargetDescription], error);
        return nil;
    }
    
    __weak typeof(self) weakSelf = self;
    _hapticEngine.stoppedHandler = ^(CHHapticEngineStoppedReason stoppedReason) {
        HapticContext* me = weakSelf;
        if (me == nil) {
            return;
        }

        Log(LOG_W, @"%@: Haptic engine stopped: %ld", [me hapticTargetDescription], (long)stoppedReason);
        me->_hapticPlayer = nil;
        me->_hapticEngine = nil;
        me->_playing = NO;
    };
    _hapticEngine.resetHandler = ^{
        HapticContext* me = weakSelf;
        if (me == nil) {
            return;
        }

        Log(LOG_W, @"%@: Haptic engine reset", [me hapticTargetDescription]);
        me->_hapticPlayer = nil;
        me->_playing = NO;
        [me->_hapticEngine startAndReturnError:nil];
    };
    
    return self;
}

-(id) initWithGamepad:(GCController*)gamepad locality:(GCHapticsLocality)locality API_AVAILABLE(ios(14.0), tvos(14.0)) {
    if (gamepad.haptics == nil) {
        Log(LOG_W, @"Controller %d does not support haptics", gamepad.playerIndex);
        return nil;
    }

    if (![[gamepad.haptics supportedLocalities] containsObject:locality]) {
        Log(LOG_W, @"Controller %d does not support haptic locality: %@", gamepad.playerIndex, locality);
        return nil;
    }

    return [self initWithHapticEngine:[gamepad.haptics createEngineWithLocality:locality]
                          playerIndex:gamepad.playerIndex];
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

+(HapticContext*) createContextForLeftTrigger:(GCController*)gamepad {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        return [[HapticContext alloc] initWithGamepad:gamepad locality:GCHapticsLocalityLeftTrigger];
    }
    else {
        return nil;
    }
}

+(HapticContext*) createContextForRightTrigger:(GCController*)gamepad {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        return [[HapticContext alloc] initWithGamepad:gamepad locality:GCHapticsLocalityRightTrigger];
    }
    else {
        return nil;
    }
}

+(HapticContext*) createContextForDeviceHaptics {
#if TARGET_OS_TV
    return nil;
#else
    if (@available(iOS 13.0, *)) {
        if (![CHHapticEngine capabilitiesForHardware].supportsHaptics) {
            Log(LOG_W, @"Device haptics are not supported on this hardware");
            return nil;
        }

        NSError* error = nil;
        CHHapticEngine* hapticEngine = [[CHHapticEngine alloc] initAndReturnError:&error];
        if (error != nil) {
            Log(LOG_W, @"Device haptics: Haptic engine creation failed: %@", error);
            return nil;
        }

        return [[HapticContext alloc] initWithHapticEngine:hapticEngine
                                                playerIndex:GCControllerPlayerIndexUnset];
    }
    else {
        return nil;
    }
#endif
}

@end
