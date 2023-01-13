//
//  KeyboardInputField.m
//  Moonlight
//
//  Created by Cameron Gutman on 12/2/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "KeyboardInputField.h"

@implementation KeyboardInputField

- (UIEditingInteractionConfiguration) editingInteractionConfiguration {
    // Suppress the Undo menu that appears with a 3 finger tap
    return UIEditingInteractionConfigurationNone;
}

@end
