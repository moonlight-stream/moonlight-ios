//
//  KeyboardMovementProfile.m
//  Moonlight
//
//  Created by Hugo on 2/20/19.
//  Copyright © 2019 Moonlight Game Streaming Project. All rights reserved.
//

#import "KeyboardMovementProfile.h"
typedef NS_ENUM(u_short, KeyCode) {
    KeyCode_w = 87,
    KeyCode_a = 65,
    KeyCode_s = 83,
    KeyCode_d = 68,
    KeyCode_q = 81,
    KeyCode_e = 69,
};

@interface KeyboardMovementProfile()
@property (nonatomic) NSMutableDictionary *downStates;
@end

@implementation KeyboardMovementProfile
- (instancetype)initWithProfile:(MovementProfile)movementProfile {
    if ((self = [super init])) {
        _activeProfile = movementProfile;
        _downStates = [NSMutableDictionary new];
    }
    return self;
}

- (NSString *)keycodeMapString:(u_short)keyCode {
    return [NSNumber numberWithShort:keyCode].description;
}

- (BOOL)downState:(u_short)keyCode {
    NSString *key = [self keycodeMapString:keyCode];
    if (!_downStates[key])
        _downStates[key] = [NSNumber numberWithBool:YES];
    return [_downStates[key] boolValue];
}

- (void)toggleDownState:(u_short)keyCode {
    NSString *key = [self keycodeMapString:keyCode];
    BOOL currState = [_downStates[key] boolValue];
    _downStates[key] = [NSNumber numberWithBool:!currState];
}

- (BOOL)keyPressState:(u_short)keyCode {
    switch (keyCode) {
        case KeyCode_w: return [self downState:keyCode];
        default: return NO;
    }
}

- (BOOL)isToggable:(u_short)keyCode {
    switch (keyCode) {
        case KeyCode_w: return YES;
        default: return NO;
    }
}

- (int)delayForKeyCode:(u_short)keyCode {
    switch (keyCode) {
        case KeyCode_q:
        case KeyCode_e:
        case KeyCode_s:
        case KeyCode_a:
        case KeyCode_d: return 300;
        case KeyCode_w: return 1000;
        default: return 50;
    }
}
@end
