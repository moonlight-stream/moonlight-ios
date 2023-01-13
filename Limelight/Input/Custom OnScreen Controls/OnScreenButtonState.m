//
//  onScreenButtonState.m
//  Moonlight
//
//  Created by Long Le on 10/20/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "OnScreenButtonState.h"

@implementation OnScreenButtonState

- (id) initWithButtonName:(NSString*)name isHidden:(BOOL)isHidden andPosition:(CGPoint)position {
    if ((self = [self init])) {
        self.name = name;
        self.isHidden = isHidden;
        self.position = position;
    }
    
    return self;
}

+ (BOOL) supportsSecureCoding {
    return YES;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeBool:self.isHidden forKey:@"isHidden"];
    [encoder encodeCGPoint:self.position forKey:@"position"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    if (self = [super init]) {
        self.name = [decoder decodeObjectForKey:@"name"];
        self.isHidden = [decoder decodeBoolForKey:@"isHidden"];
        self.position = [decoder decodeCGPointForKey:@"position"];
    }
    
    return self;
}

@end
