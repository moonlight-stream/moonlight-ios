//
//  TextFieldKeyboardDelegate.h
//  Moonlight
//
//  Created by Cameron Gutman on 3/24/20.
//  Copyright © 2020 Moonlight Game Streaming Project. All rights reserved.
//

#pragma once

#import <UIKit/UIKit.h>

@interface TextFieldKeyboardDelegate : NSObject<UITextFieldDelegate>

- (id)initWithTextField:(UITextField*)textField;
- (NSArray<UIKeyCommand *> *)keyCommands;

@end
