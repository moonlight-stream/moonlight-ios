//
//  StreamView.m
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "StreamView.h"
#include <Limelight.h>
#import "OnScreenControls.h"
#import "DataManager.h"
#import "ControllerSupport.h"
#import "keyboard_translation.h"

@implementation StreamView {
    CGPoint touchLocation;
    BOOL touchMoved;
    OnScreenControls* onScreenControls;
    
    BOOL isDragging;
    NSTimer* dragTimer;
    
    float xDeltaFactor;
    float yDeltaFactor;
    float screenFactor;
    
    BOOL preventNextTouchRelease;
    NSTimer* preventNextTouchReleaseTimer;
}

- (void) setMouseDeltaFactors:(float)x y:(float)y {
    xDeltaFactor = x;
    yDeltaFactor = y;
    
    screenFactor = [[UIScreen mainScreen] scale];
}

- (void) setupOnScreenControls:(ControllerSupport*)controllerSupport swipeDelegate:(id<EdgeDetectionDelegate>)swipeDelegate {
    onScreenControls = [[OnScreenControls alloc] initWithView:self controllerSup:controllerSupport swipeDelegate:swipeDelegate];
    DataManager* dataMan = [[DataManager alloc] init];
    OnScreenControlsLevel level = (OnScreenControlsLevel)[[dataMan getSettings].onscreenControls integerValue];
    
    if (level == OnScreenControlsLevelAuto) {
        [controllerSupport initAutoOnScreenControlMode:onScreenControls];
    }
    else {
        Log(LOG_I, @"Setting manual on-screen controls level: %d", (int)level);
        [onScreenControls setLevel:level];
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    Log(LOG_D, @"Touch down");
    if (![onScreenControls handleTouchDownEvent:touches]) {
        UITouch *touch = [[event allTouches] anyObject];
        touchLocation = [touch locationInView:self];
        touchMoved = false;
        if ([[event allTouches] count] == 1 && !isDragging) {
            dragTimer = [NSTimer scheduledTimerWithTimeInterval:0.650
                                                     target:self
                                                   selector:@selector(onDragStart:)
                                                   userInfo:nil
                                                    repeats:NO];
        } else if ([[event allTouches] count] == 3 && !isDragging) {
            //Invalidate the drag timer, the keyboard will be opened on release
            [dragTimer invalidate];
            dragTimer = nil;
        }
    }
}

- (void)onDragStart:(NSTimer*)timer {
    if (!touchMoved && !isDragging){
        isDragging = true;
        LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
    }
}

- (void)onCancelPreventNextTouch:(NSTimer*)timer {
    preventNextTouchRelease = false;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (![onScreenControls handleTouchMovedEvent:touches]) {
        [dragTimer invalidate];
        dragTimer = nil;
        if ([[event allTouches] count] == 1) {
            UITouch *touch = [[event allTouches] anyObject];
            CGPoint currentLocation = [touch locationInView:self];
            
            if (touchLocation.x != currentLocation.x ||
                touchLocation.y != currentLocation.y)
            {
                int deltaX = currentLocation.x - touchLocation.x;
                int deltaY = currentLocation.y - touchLocation.y;
                
                deltaX *= xDeltaFactor * screenFactor;
                deltaY *= yDeltaFactor * screenFactor;
                
                if (deltaX != 0 || deltaY != 0) {
                    LiSendMouseMoveEvent(deltaX, deltaY);
                    touchMoved = true;
                    touchLocation = currentLocation;
                }
            }
        } else if ([[event allTouches] count] == 2) {
            CGPoint firstLocation = [[[[event allTouches] allObjects] objectAtIndex:0] locationInView:self];
            CGPoint secondLocation = [[[[event allTouches] allObjects] objectAtIndex:1] locationInView:self];
            
            CGPoint avgLocation = CGPointMake((firstLocation.x + secondLocation.x) / 2, (firstLocation.y + secondLocation.y) / 2);
            if (touchLocation.y != avgLocation.y) {
                LiSendScrollEvent(avgLocation.y - touchLocation.y);
            }
            touchMoved = true;
            touchLocation = avgLocation;
        }
    }
    
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    Log(LOG_D, @"Touch up");
    if (![onScreenControls handleTouchUpEvent:touches]) {
        [dragTimer invalidate];
        dragTimer = nil;
        if (!touchMoved && !preventNextTouchRelease) {
            if ([[event allTouches] count]  == 3) {
                Log(LOG_D, @"Opening the keyboard");
                //Prepare the textbox used to capture entered characters
                _textToSend.delegate = self;
                _textToSend.text = @"0";
                [_textToSend becomeFirstResponder];
                [_textToSend addTarget:self action:@selector(onKeyboardPressed:) forControlEvents:UIControlEventEditingChanged];
                
                //This timer is usefull to prevent to send a touch if you do not release the 3 fingers at the exact same time
                preventNextTouchRelease = true;
                preventNextTouchReleaseTimer = [NSTimer scheduledTimerWithTimeInterval:0.250
                                                             target:self
                                                           selector:@selector(onCancelPreventNextTouch:)
                                                           userInfo:nil
                                                            repeats:NO];
            } else if ([[event allTouches] count]  == 2) {
                Log(LOG_D, @"Sending right mouse button press");
                
                LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
                
                // Wait 100 ms to simulate a real button press
                usleep(100 * 1000);
                
                LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
            } else if ([[event allTouches] count]  == 1){
                if (!isDragging){
                    Log(LOG_D, @"Sending left mouse button press");
                    
                    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
                    
                    // Wait 100 ms to simulate a real button press
                    usleep(100 * 1000);
                }
                isDragging = false;
                LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
            }
        }
        else if (isDragging) {
            isDragging = false;
            LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
        }
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
}

//Detect and send the ENTER key
- (BOOL)textFieldShouldReturn:(UITextField *)textToSend {
    LiSendKeyboardEvent(0x0d, KEY_ACTION_DOWN, 0);
    usleep(100 * 1000);
    LiSendKeyboardEvent(0x0d, KEY_ACTION_UP, 0);
    return YES;
}

//Capture the keycode of the last entered character in the textToSend Textfield, translate it and send it to GFE
-(void)onKeyboardPressed :(UITextField *)textToSend{
    struct translatedKeycode keyCodeStructure;
    if ([textToSend.text  isEqual: @""]){
        //If the textfield is empty, send a BACKSPACE
        keyCodeStructure.keycode = 8;
        keyCodeStructure.modifier = 0;
    } else {
        //Translate the keycode of the last entered character
        short keyCode = [textToSend.text characterAtIndex:1];
        keyCodeStructure = translateKeycode(keyCode);
    }
    //Send the keycode
    LiSendKeyboardEvent(keyCodeStructure.keycode, KEY_ACTION_DOWN, keyCodeStructure.modifier);
    usleep(100 * 1000);
    LiSendKeyboardEvent(keyCodeStructure.keycode, KEY_ACTION_UP, keyCodeStructure.modifier);
    textToSend.text = @"0";
}

@end
