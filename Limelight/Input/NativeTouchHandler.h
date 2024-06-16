//
//  NativeTouchHandler.h
//  Moonlight
//
//  Created by ZWM on 2024/6/16.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//


#import "StreamView.h"
#import "DataManager.h"
#include <Limelight.h>

NS_ASSUME_NONNULL_BEGIN

@interface NativeTouchHandler : UIResponder

- (id)initWith:(StreamView*)view and:(TemporarySettings*)settings;


@end

NS_ASSUME_NONNULL_END
