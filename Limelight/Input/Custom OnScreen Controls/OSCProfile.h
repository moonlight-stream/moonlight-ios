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

/**
 This object contains information pertaining to any of the user created, custom on screen controller layout configurations, or 'profiles.' The object contains a 'name' property for easy reference, as well as an 'isSelected' property which is used to determine whether this particular custom OSC layout should show on screen during game stream view. Only one 'OSCProfile' is set to 'isSelected' at any given time. The object also contains an array of 'OnScreenButtonStates' which provides information that allows us to move and hide/unhide each of the 19 on screen buttons. Note that the 'buttonStates' property should contain an NSMutableArray of ENCODED 'OnScreenButtonState' objects. This allows us to save the 'OSCProfile' object to NSUserDefaults.
 Additionally the 'OSCProfile' object adopts encoding and decoding protocols so that we can encode the object before saving it to NSUserDefaults. By saving this object to NSUserDefaults we allow the user to save and load their custom on screen controller button layouts between app launches
 */
@interface OSCProfile : NSObject <NSCoding, NSSecureCoding>

@property NSString *name;
@property NSMutableArray <OnScreenButtonState *> *buttonStates;
@property BOOL isSelected;

- (id) initWithName:(NSString*)name buttonStates:(NSMutableArray*)buttonStates isSelected:(BOOL)isSelected;

+ (BOOL) supportsSecureCoding;
- (id) initWithCoder:(NSCoder*)decoder;
- (void) encodeWithCoder:(NSCoder*)encoder;

@end

NS_ASSUME_NONNULL_END
