//
//  OSCProfile.m
//  Moonlight
//
//  Created by Long Le on 12/22/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "OSCProfile.h"

@implementation OSCProfile

+ (BOOL) supportsSecureCoding
{
    return YES;
}

- (id) initWithName:(NSString*)name buttonStates:(NSMutableArray*)buttonStates isSelected:(BOOL)isSelected {
    if ((self = [self init])) {
        
        self.name = name;
        self.buttonStates = buttonStates;
        self.isSelected = isSelected;
    }
    
    return self;
}

- (void) encodeWithCoder:(NSCoder*)encoder {
    [encoder encodeObject:self.name forKey:@"name"];
    [encoder encodeObject:self.buttonStates forKey:@"buttonStates"];
    [encoder encodeBool:self.isSelected forKey:@"isSelected"];
}

- (id) initWithCoder:(NSCoder*)decoder {
    
    if (self = [super init]) {
        
        self.name = [decoder decodeObjectForKey:@"name"];
        self.buttonStates = [decoder decodeObjectForKey:@"buttonStates"];
        self.isSelected = [decoder decodeBoolForKey:@"isSelected"];
    }
    
    return self;
}

@end
