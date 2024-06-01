//
//  NativeTouchHandler.h
//  Moonlight
//
//  Created by ZWM on 2024/5/14.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import "StreamView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TouchPointer : NSObject

+ (void)initContextWith:(StreamView *)view;
+ (void)populatePointerId:(UITouch*)touch;
+ (void)removePointerId:(UITouch*)touch;
+ (uint32_t) retrievePointerIdFromDict:(UITouch*)touch;
+ (void)setPointerVelocityDivider:(CGFloat)dividerLocation;
+ (void)setPointerVelocityFactor:(CGFloat)velocityFactor;
+ (void)populatePointerObjIntoDict:(UITouch*)touch;
+ (void)removePointerObjFromDict:(UITouch*)touch;
+ (void)updatePointerObjInDict:(UITouch *)touch;
+ (CGPoint)selectCoordsFor:(UITouch *)touch;


- (instancetype)initWith:(UITouch *)touch;
@end




NS_ASSUME_NONNULL_END

