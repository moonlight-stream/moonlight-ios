//
//  KeyboardMovementProfile.h
//  Moonlight
//
//  Created by Hugo on 2/20/19.
//  Copyright © 2019 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, MovementProfile) {
    MovementProfileWasd,
    MovementProfileDefault
};

@interface KeyboardMovementProfile : NSObject
@property (readonly, nonatomic, assign) MovementProfile activeProfile;
- (instancetype)initWithProfile:(MovementProfile)movementProfile;
- (int)delayForKeyCode:(u_short)keyCode;
/**
 *  @description
 *      Current key state for the pressed keycode.
 *      True indicates the key is down, false indicates its up.
 *      Each keycode state begins in the down state.
 */
- (BOOL)keyPressState:(u_short)keyCode;
/**
 *  @description
 *      Whether or not the keycode state is toggable.
 */
- (BOOL)isToggable:(u_short)keyCode;
/**
 *  @description
 *      Toggles the down state of the keycode.
 */
- (void)toggleDownState:(u_short)keyCode;
@end

NS_ASSUME_NONNULL_END
