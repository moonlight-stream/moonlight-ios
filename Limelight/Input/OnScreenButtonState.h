//
//  onScreenButtonState.h
//  Moonlight
//
//  Created by Long Le on 10/20/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OnScreenButtonState : NSObject  <NSCoding, NSSecureCoding>

@property NSString *name;
@property CGPoint position;

- (id)initWithButtonName:(NSString*)name andPosition:(CGPoint) position;
- (void)encodeWithCoder: (NSCoder*) encoder;
- (id)initWithCoder:(NSCoder*) decoder;
+ (BOOL)supportsSecureCoding;

@end

NS_ASSUME_NONNULL_END
