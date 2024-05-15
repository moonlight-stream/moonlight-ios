//
//  NativeTouchHandler.m
//  Moonlight
//
//  Created by ZWM on 2024/5/14.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "NativeTouchHandler.h"

#include <Limelight.h>


// Use a Dictionary to store UITouch object's memory address as key, and pointerId as value,字典存放UITouch对象地址和pointerId映射关系
// pointerId will be generated from electronic noise, by arc4_random, pointerId,由随机噪声生成
// Use a NSSet store pointerId, for quick repeition inquiry, NSSet存放活跃的pointerId合集,用于快速查找,以防重复.
static NSMutableDictionary *pointerIdDict; //pointerId Dict for native touch.
static NSMutableSet<NSNumber *> *pointerIdSet; //pointerIdSet for native touch.

@implementation NativeTouchHandler {
    StreamView* view;
}

- (id)initWithView:(StreamView*)view {
    self = [self init];
    self->view = view;
    return self;
}


+ (NSMutableDictionary* )initializePointerIdDict {
    return pointerIdDict = [NSMutableDictionary dictionary];
}

+ (NSMutableSet* )initializePointerIdSet {
    return pointerIdSet = [NSMutableSet set];
}


// 随机生成pointerId并填入NSDict和NSSet
// generate & populate pointerId into NSDict & NSSet, called in UITouchPhaseBegan
+ (void)populatePointerId:(UITouch*)event{
    uint64_t eventAddrValue = (uint64_t)event;
    uint32_t randomPointerId = arc4random_uniform(UINT32_MAX); // generate pointerId from eletronic noise.
    while(true){
        if([pointerIdSet containsObject:@(randomPointerId)]) randomPointerId = arc4random_uniform(UINT32_MAX); // in case of new pointerId collides with existing ones, generate again.
        else{ // populate pointerId into NSDict & NSSet.
            [pointerIdDict setObject:@(randomPointerId) forKey:@(eventAddrValue)];
            [pointerIdSet addObject:@(randomPointerId)];
            return;
        }
    }
}

// remove pointerId in UITouchPhaseEnded condition
+ (void)removePointerId:(UITouch*)event{
    uint64_t eventAddrValue = (uint64_t)event;
    NSNumber* pointerIdObj = [pointerIdDict objectForKey:@(eventAddrValue)];
    if(pointerIdObj != nil){
        [pointerIdSet removeObject:pointerIdObj];
        [pointerIdDict removeObjectForKey:@(eventAddrValue)];
    }
}

// 从字典中获取UITouch事件对应的pointerId
// call this only when NSDcit & NSSet is up-to-date.
+ (uint32_t) retrievePointerIdFromDict:(UITouch*)event{
    return [[pointerIdDict objectForKey:@((uint64_t)event)] unsignedIntValue];
}



@end
