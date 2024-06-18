//
//  CustomTapGestureRecognizer.m
//  Moonlight
//
//  Created by ZWM on 2024/5/15.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "CustomTapGestureRecognizer.h"

// The most accurate & reliable tap gesture recognizer of iOS:
// - Almost 100% recoginition rate. UITapGestureRecognizer of Apple API fails frequently, just intractable.
// - When immediateTriggering is set to false (for native multi-touch):
//   Gesture signal will be triggered on touchesEnded stage, multi finger touch operations will not be interrupted by the arising keyboard.
//   Instances of different [numberOfTouchesRequired] barely compete with each other, for example, the chance of 3-finger gesture get triggered by 4 or 5 finger tap is very small.
// - Set property immediateTriggering to true, to ensure the priority of keyboard toggle in non-native touch mode, in compete with 2-finger gestures.
// - This recognizer also provides properties like gestureCapturedTime, to be accessed outside the class for useful purpose.

@implementation CustomTapGestureRecognizer

static CGFloat screenHeightInPoints;

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action {
    self = [super initWithTarget:target action:action];
    screenHeightInPoints = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    lowestTouchPointYCoord = 0.0;
    _numberOfTouchesRequired = 3;
    _immediateTriggering = false;
    _tapDownTimeThreshold = 0.3;
    _gestureCaptured = false;
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // Check if the number of touches and taps meets the required criteria
    if ([[event allTouches] count] == _numberOfTouchesRequired) {
        _gestureCapturedTime = CACurrentMediaTime();
        _gestureCaptured = true;
        for(UITouch *touch in [event allTouches]){
            if(lowestTouchPointYCoord < [touch locationInView:self.view].y) lowestTouchPointYCoord = [touch locationInView:self.view].y;
        }
        _lowestTouchPointHeight = screenHeightInPoints - lowestTouchPointYCoord;
        if(_immediateTriggering){
            lowestTouchPointYCoord = 0.0; //reset for next recoginition
            self.state = UIGestureRecognizerStateRecognized;
            return;
        }
        self.state = UIGestureRecognizerStatePossible;
    }
    if ([[event allTouches] count] > _numberOfTouchesRequired) {
        _gestureCaptured = false;
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // [super touchesEnded:touches withEvent:event];
    if(_immediateTriggering) return;
    if([[event allTouches] count] > _numberOfTouchesRequired) {
        _gestureCaptured = false;
        self.state = UIGestureRecognizerStateFailed;
    } else if(_gestureCaptured && [[event allTouches] count] == [touches count]){
        _gestureCaptured = false; //reset for next recognition
        if((CACurrentMediaTime() - _gestureCapturedTime) < _tapDownTimeThreshold){
            lowestTouchPointYCoord = 0.0; //reset for next recognition
            self.state = UIGestureRecognizerStateRecognized;
        }
    }
}

@end
