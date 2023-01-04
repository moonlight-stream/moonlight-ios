//
//  OSCProfile.h
//  Moonlight
//
//  Created by Long Le on 12/22/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OnScreenButtonState.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSCProfile : NSObject <NSCoding, NSSecureCoding>

@property NSString *name;
@property NSMutableArray <OnScreenButtonState *> *buttonStates;
@property BOOL isSelected;

- (id) initWithName:(NSString*)name buttonStates:(NSMutableArray*)buttonStates
        isSelected:(BOOL)isSelected;
- (id) initWithCoder:(NSCoder*)decoder;
- (void) encodeWithCoder:(NSCoder*)encoder;
+ (BOOL) supportsSecureCoding;

@end

NS_ASSUME_NONNULL_END
