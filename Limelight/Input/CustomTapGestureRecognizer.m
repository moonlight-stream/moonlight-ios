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

// The most accurate & reliable tap gesture recognizer of iOS with almost 100% recoginition rate, instances of different numberOfTouchesRequired barely compete with each other. UITapGestureRecognizer of Apple API is just intractable.
// Known issue: not reliable in absolute touch mode, since it competes with 2 finger zoom-in & out gestures from original moonlight
@implementation CustomTapGestureRecognizer

static CGFloat screenHeightInPoints;

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action {
    self = [super initWithTarget:target action:action];
    screenHeightInPoints = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    lowestTouchPointYCoord = 0.0;
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
        self.state = UIGestureRecognizerStatePossible;
    }
    if ([[event allTouches] count] > _numberOfTouchesRequired) {
        _gestureCaptured = false;
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // [super touchesEnded:touches withEvent:event];
    if ([[event allTouches] count] > _numberOfTouchesRequired) {
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
