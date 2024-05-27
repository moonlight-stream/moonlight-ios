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

@implementation CustomTapGestureRecognizer

static NSTimeInterval multiFingerDownTime;
static bool multiFingerDown;
static CGFloat screenHeightInPoints;
static CGFloat lowestTouchPointYCoord = 0.0;

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action {
    self = [super initWithTarget:target action:action];
    screenHeightInPoints = CGRectGetHeight([[UIScreen mainScreen] bounds]);
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // Check if the number of touches and taps meets the required criteria
    if ([[event allTouches] count] == _numberOfTouchesRequired) {
        multiFingerDownTime = CACurrentMediaTime();
        multiFingerDown = true;
        
        for(UITouch *touch in [event allTouches]){
            if(lowestTouchPointYCoord < [touch locationInView:self.view].y) lowestTouchPointYCoord = [touch locationInView:self.view].y;
        }
        _lowestTouchPointHeight = screenHeightInPoints - lowestTouchPointYCoord;
        self.state = UIGestureRecognizerStatePossible;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // [super touchesEnded:touches withEvent:event];
    if(multiFingerDown && [[event allTouches] count] == [touches count]){
        multiFingerDown = false;
        if((CACurrentMediaTime() - multiFingerDownTime) < _tapDownTimeThreshold / 1000){
            lowestTouchPointYCoord = 0.0; //reset for next recognition
            self.state = UIGestureRecognizerStateRecognized;
        }
    }
}

+ (CGFloat)lowestTouchPointHeight{
    @synchronized (self){
        return self.lowestTouchPointHeight;
    }
}

@end
