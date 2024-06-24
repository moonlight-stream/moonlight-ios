//
//  NativeTouchPointer.m
//  Moonlight
//
//  Created by ZWM on 2024/5/14.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NativeTouchPointer.h"
#include <Limelight.h>

// native touch pointer ojbect that stores & manipulates touch coordinates

static NSMutableDictionary *pointerObjDict;

static CGFloat pointerVelocityFactor;
static CGFloat pointerVelocityDivider;
static CGFloat pointerVelocityDividerLocationByPoints;

StreamView *streamView;

@implementation NativeTouchPointer{
    CGPoint initialPoint;
    CGPoint latestPoint;
    CGPoint previousPoint;
    CGPoint latestRelativePoint;
    CGPoint previousRelativePoint;
}

+ (void)setPointerVelocityDivider:(CGFloat)dividerLocation{
    pointerVelocityDivider = dividerLocation;
}

+ (void)setPointerVelocityFactor:(CGFloat)velocityFactor{
    pointerVelocityFactor = velocityFactor;
}


- (instancetype)initWithTouch:(UITouch *)touch{
    self = [super init];
    self->initialPoint = [touch locationInView:streamView];
    self->latestPoint = self->initialPoint;
    self->latestRelativePoint = self->initialPoint;
    return self;
}

- (void)updatePointerCoords:(UITouch *)touch{
    previousPoint = latestPoint;
    latestPoint = [touch locationInView:streamView];
    previousRelativePoint = latestRelativePoint;
    latestRelativePoint.x = previousRelativePoint.x + pointerVelocityFactor * (latestPoint.x - previousPoint.x);
    latestRelativePoint.y = previousRelativePoint.y + pointerVelocityFactor * (latestPoint.y - previousPoint.y);
}

+ (void)initContextWithView:(StreamView *)view{
    streamView = view;
    pointerObjDict = [NSMutableDictionary dictionary];
    pointerVelocityDividerLocationByPoints = CGRectGetWidth([[UIScreen mainScreen] bounds]) * pointerVelocityDivider;
    NSLog(@"pointerVelocityDivider:  %.2f", pointerVelocityDivider);
    NSLog(@"pointerVelocityDividerLocationByPoints:  %.2f", pointerVelocityDividerLocationByPoints);
}

+ (void)populatePointerObjIntoDict:(UITouch*)touch{
    [pointerObjDict setObject:[[NativeTouchPointer alloc] initWithTouch:touch] forKey:@((uintptr_t)touch)];
}

+ (void)removePointerObjFromDict:(UITouch*)touch{
    uintptr_t memAddrValue = (uintptr_t)touch;
    NativeTouchPointer* pointer = [pointerObjDict objectForKey:@(memAddrValue)];
    if(pointer != nil){
        [pointerObjDict removeObjectForKey:@(memAddrValue)];
    }

}

+ (void)updatePointerObjInDict:(UITouch *)touch{
    [[pointerObjDict objectForKey:@((uintptr_t)touch)] updatePointerCoords:touch];
}


+ (CGPoint)selectCoordsFor:(UITouch *)touch{
    NativeTouchPointer *pointer = [pointerObjDict objectForKey:@((uintptr_t)touch)];
    if((pointer -> initialPoint).x > pointerVelocityDividerLocationByPoints){  //if first contact coords locates on the right side of divider.
        return pointer->latestRelativePoint;
    }
    return [touch locationInView:streamView];
}




@end
