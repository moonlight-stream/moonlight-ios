//
//  keyboard_translation.h
//  Moonlight
//
//  Created by Mimiste on 05/10/2016.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

#ifndef keyboard_translation_h
#define keyboard_translation_h

struct translatedKeycode{
    short keycode;
    short modifier;
};

struct translatedKeycode translateKeycode(short keyCode);

#endif /* keyboard_translation_h */
