//
//  onScreenButtonState.m
//  Moonlight
//
//  Created by Long Le on 10/20/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "OnScreenButtonState.h"

@implementation OnScreenButtonState

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (id)initWithButtonName:(NSString*)name andPosition:(CGPoint) position {
    
    if ((self = [self init])) {
        
        self.name = name;
        self.position = position;
    }
    
    return self;
}

- (void)encodeWithCoder: (NSCoder*) encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeCGPoint:self.position forKey:@"position"];
}

- (id)initWithCoder:(NSCoder*) decoder {
    
    if (self = [super init]) {
        
        self.name = [decoder decodeObjectForKey:@"name"];
        self.position = [decoder decodeCGPointForKey:@"position"];
    }
    
    return self;
}

@end
