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

@implementation CustomEdgeSwipeGestureRecognizer {
    CGPoint _startPoint;
    CGFloat _nomarlizedswipeThreshold;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    
    UITouch *touch = [touches anyObject];
    _startPoint = [touch locationInView:self.view];
    // Log(LOG_I, @"start point x: %f", _startPoint.x);
}


- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    CGRect screenBounds = [[UIScreen mainScreen] bounds];// Get the screen's bounds (in points)
    CGFloat screenWidthInPoints = CGRectGetWidth(screenBounds);
    // CGFloat screenHeightInPoints = CGRectGetHeight(screenBounds);
    // Log the screen resolution
    // NSLog(@"Screen resolution: %.0f x %.0f points", screenWidthInPoints, screenHeightInPoints);

    
    [super touchesMoved:touches withEvent:event];
    UITouch *touch = [touches anyObject];
    CGPoint gestureEndPoint = [touch locationInView:self.view];
    CGFloat nomarlizedgestureEndPointXDelta = (gestureEndPoint.x-_startPoint.x)/screenWidthInPoints;
    // CGFloat nomarlizedgestureEndPointYDelta = (gestureEndPoint.y-_startPoint.y)/screenHeightInPoints;
    // Log(LOG_I, @"current point x: %f", nomarlizedgestureEndPointXDelta);

    _nomarlizedswipeThreshold = 0.5; // You need swipe half of screen width from left edge to trigger this Recognizer
    if (_startPoint.x == 0.0 && nomarlizedgestureEndPointXDelta > _nomarlizedswipeThreshold) {
        // Detected a swipe from the left edge that exceeds _nomarlizedswipeThreshold
        if (self.state == UIGestureRecognizerStatePossible) {
            self.state = UIGestureRecognizerStateBegan;
        }
    } else {
        self.state = UIGestureRecognizerStateFailed;
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesCancelled:touches withEvent:event];
    
    self.state = UIGestureRecognizerStateFailed;
}

@end
