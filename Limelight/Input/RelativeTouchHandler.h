//
//  RelativeTouchHandler.h
//  Moonlight
//
//  Created by Cameron Gutman on 11/1/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#import "StreamView.h"

NS_ASSUME_NONNULL_BEGIN

@interface RelativeTouchHandler : UIResponder

-(id)initWithView:(StreamView*)view sensitivityMultiplier:(float)sensitivityMultiplier;

@end

NS_ASSUME_NONNULL_END
