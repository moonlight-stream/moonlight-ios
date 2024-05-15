//
//  CustomTapGestureRecognizer.m
//  Moonlight
//
//  Created by Admin on 2024/5/15.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIGestureRecognizerSubclass.h>
#import "CustomTapGestureRecognizer.h"

@implementation CustomTapGestureRecognizer

static NSTimeInterval multiFingerDownTime;
static bool multiFingerDown;

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action {
    self = [super initWithTarget:target action:action];
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // Check if the number of touches and taps meets the required criteria
    if ([[event allTouches] count] == _numberOfTouchesRequired) {
        multiFingerDownTime = CACurrentMediaTime();
        multiFingerDown = true;
        self.state = UIGestureRecognizerStatePossible;
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // [super touchesEnded:touches withEvent:event];
    if(multiFingerDown && [[event allTouches] count] == [touches count]){
        multiFingerDown = false;
        if((CACurrentMediaTime() - multiFingerDownTime) < _tapDownTimeThreshold / 1000) self.state = UIGestureRecognizerStateRecognized;
    }
}

@end
