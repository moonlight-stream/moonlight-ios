//
//  CustomEdgeSwipeGestureRecognizer.m
//  Moonlight-ZWM
//
//  Created by ZWM on 2024/4/30.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

// #import <Foundation/Foundation.h>

#import "CustomEdgeSwipeGestureRecognizer.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

@implementation CustomEdgeSwipeGestureRecognizer
UITouch* capturedUITouch;
CGFloat _startPointX;
static CGFloat screenWidthInPoints;
static CGFloat EDGE_TOLERANCE_POINTS = 50.0f;

- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action {
    self = [super initWithTarget:target action:action];
    screenWidthInPoints = CGRectGetWidth([[UIScreen mainScreen] bounds]); // Get the screen's bounds (in points)
    return self;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // [super touchesBegan:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    capturedUITouch = touch;
    _startPointX = [capturedUITouch locationInView:self.view].x;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    // [super touchesEnded:touches withEvent:event];
    
    if([touches containsObject:capturedUITouch]){
        CGFloat _endPointX = [capturedUITouch locationInView:self.view].x;
        CGFloat normalizedGestureDistance = fabs(_endPointX - _startPointX)/screenWidthInPoints;
        
        if(self.edges & UIRectEdgeLeft){
            if(_startPointX < EDGE_TOLERANCE_POINTS && normalizedGestureDistance > _normalizedThresholdDistance){
                self.state = UIGestureRecognizerStateBegan;
                self.state = UIGestureRecognizerStateEnded;
            }
            // NSLog(@"_startPointX  %f , normalizedGestureDeltaX %f", _startPointX,  normalizedGestureDistance);
        }
        if(self.edges & UIRectEdgeRight){
            if((_startPointX > (screenWidthInPoints - EDGE_TOLERANCE_POINTS)) && normalizedGestureDistance > _normalizedThresholdDistance){
                self.state = UIGestureRecognizerStateBegan;
                self.state = UIGestureRecognizerStateEnded;
            }
           // NSLog(@"_startPointX  %f , normalizedGestureDeltaX %f", _startPointX,  normalizedGestureDistance);
        }
    }
}

@end





