//
//  AbsoluteTouchHandler.m
//  Moonlight
//
//  Created by Cameron Gutman on 11/1/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#import "AbsoluteTouchHandler.h"

#include <Limelight.h>

// How long the fingers must be stationary to start a right click
#define LONG_PRESS_ACTIVATION_DELAY 0.650f

// How far the finger can move before it cancels a right click
#define LONG_PRESS_ACTIVATION_DELTA 0.01f

// How long the double tap deadzone stays in effect between touch up and touch down
#define DOUBLE_TAP_DEAD_ZONE_DELAY 0.250f

// How far the finger can move before it can override the double tap deadzone
#define DOUBLE_TAP_DEAD_ZONE_DELTA 0.025f

// How long to wait after the first finger lands before pressing the left button.
// If a second finger lands within this window the gesture is a two-finger gesture
// (e.g. scrolling), so no click must reach the host.
#define LEFT_PRESS_DELAY 0.040f

// How far the finger can move during LEFT_PRESS_DELAY before the press is sent early (a drag)
#define LEFT_PRESS_EARLY_MOVE_DELTA 0.005f

@implementation AbsoluteTouchHandler {
    StreamView* view;
    
    NSTimer* longPressTimer;
    NSTimer* leftPressTimer;
    BOOL leftButtonDown;
    UITouch* lastTouchDown;
    CGPoint lastTouchDownLocation;
    UITouch* lastTouchUp;
    CGPoint lastTouchUpLocation;
}

- (id)initWithView:(StreamView*)view {
    self = [self init];
    self->view = view;
    return self;
}

- (void)onLongPressStart:(NSTimer*)timer {
    // Raise the left click and start a right click
    [self releaseLeftButton];
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
}

- (void)pressLeftButton {
    [leftPressTimer invalidate];
    leftPressTimer = nil;
    if (!leftButtonDown) {
        leftButtonDown = YES;
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
    }
}

- (void)onLeftPressDelayElapsed:(NSTimer*)timer {
    [self pressLeftButton];
}

- (void)releaseLeftButton {
    [leftPressTimer invalidate];
    leftPressTimer = nil;
    if (leftButtonDown) {
        leftButtonDown = NO;
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
    }
}

// A second finger landed: this is a multi-finger gesture, not a click or drag.
- (void)abortSingleFingerGesture {
    [longPressTimer invalidate];
    longPressTimer = nil;
    [self releaseLeftButton];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    // Ignore touch down events with more than one finger
    if ([[event allTouches] count] > 1) {
        [self abortSingleFingerGesture];
        return;
    }
    
    UITouch* touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:view];
    
    // Don't reposition for finger down events within the deadzone. This makes double-clicking easier.
    if (touch.timestamp - lastTouchUp.timestamp > DOUBLE_TAP_DEAD_ZONE_DELAY ||
        sqrt(pow((touchLocation.x / view.bounds.size.width) - (lastTouchUpLocation.x / view.bounds.size.width), 2) +
             pow((touchLocation.y / view.bounds.size.height) - (lastTouchUpLocation.y / view.bounds.size.height), 2)) > DOUBLE_TAP_DEAD_ZONE_DELTA) {
        [view updateCursorLocation:touchLocation isMouse:NO];
    }
    
    // Press the left button down, after a short delay so that a second finger
    // landing right behind the first doesn't produce a stray click.
    [leftPressTimer invalidate];
    leftPressTimer = [NSTimer scheduledTimerWithTimeInterval:LEFT_PRESS_DELAY
                                                      target:self
                                                    selector:@selector(onLeftPressDelayElapsed:)
                                                    userInfo:nil
                                                     repeats:NO];
    
    // Start the long press timer
    longPressTimer = [NSTimer scheduledTimerWithTimeInterval:LONG_PRESS_ACTIVATION_DELAY
                                                      target:self
                                                    selector:@selector(onLongPressStart:)
                                                    userInfo:nil
                                                     repeats:NO];
    
    lastTouchDown = touch;
    lastTouchDownLocation = touchLocation;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    // Ignore touch move events with more than one finger
    if ([[event allTouches] count] > 1) {
        [self abortSingleFingerGesture];
        return;
    }

    UITouch* touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:view];

    if (leftPressTimer != nil) {
        // Tiny finger jitter while waiting for the delayed press must not end the wait
        // early, or a second finger landing right behind would still cause a click.
        if (sqrt(pow((touchLocation.x / view.bounds.size.width) - (lastTouchDownLocation.x / view.bounds.size.width), 2) +
                 pow((touchLocation.y / view.bounds.size.height) - (lastTouchDownLocation.y / view.bounds.size.height), 2)) <= LEFT_PRESS_EARLY_MOVE_DELTA) {
            return;
        }

        // The finger is dragging, so the press must be active before the cursor moves
        [self pressLeftButton];
    }

    if (sqrt(pow((touchLocation.x / view.bounds.size.width) - (lastTouchDownLocation.x / view.bounds.size.width), 2) +
             pow((touchLocation.y / view.bounds.size.height) - (lastTouchDownLocation.y / view.bounds.size.height), 2)) > LONG_PRESS_ACTIVATION_DELTA) {
        // Moved too far since touch down. Cancel the long press timer.
        [longPressTimer invalidate];
        longPressTimer = nil;
    }
    
    [view updateCursorLocation:[[touches anyObject] locationInView:view] isMouse:NO];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    // Only fire this logic if all touches have ended
    if ([[event allTouches] count] == [touches count]) {
        // Cancel the long press timer
        [longPressTimer invalidate];
        longPressTimer = nil;

        // A quick tap can end before the delayed press fired. Press now so it still clicks.
        if (leftPressTimer != nil) {
            [self pressLeftButton];
        }

        // Left button up on finger up
        [self releaseLeftButton];

        // Raise right button too in case we triggered a long press gesture
        LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
        
        // Remember this last touch for touch-down deadzoning
        lastTouchUp = [touches anyObject];
        lastTouchUpLocation = [lastTouchUp locationInView:view];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    // Treat this as a normal touchesEnded event
    [self touchesEnded:touches withEvent:event];
}

@end
