//
//  NativeTouchHandler.h
//  Moonlight
//
//  Created by ZWM on 2024/5/14.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import "StreamView.h"

NS_ASSUME_NONNULL_BEGIN

@interface NativeTouchHandler : UIResponder

+ (NSMutableDictionary* )initializePointerIdDict;
+ (NSMutableSet* )initializePointerIdSet;
+ (void)populatePointerId:(UITouch*)event;
+ (void)removePointerId:(UITouch*)event;
+ (uint32_t) retrievePointerIdFromDict:(UITouch*)event;


-(id)initWithView:(StreamView*)view;

@end

NS_ASSUME_NONNULL_END

