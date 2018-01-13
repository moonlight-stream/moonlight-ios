//
//  keyboard_translation.m
//  Moonlight
//
//  Created by Mimiste on 05/10/2016.
//  Copyright © 2016 Moonlight Stream. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "keyboard_translation.h"

struct translatedKeycode translateKeycode(short keyCode) {
    struct translatedKeycode translatedKeycodeStructure;
    
    translatedKeycodeStructure.modifier = 0;
    translatedKeycodeStructure.keycode = 0;
    
    //Letters uppercase
    if (keyCode >= 65 && keyCode <= 90){
        translatedKeycodeStructure.keycode = keyCode;
        translatedKeycodeStructure.modifier = 0x01;
    }
    
    //Numbers
    if (keyCode >= 48 && keyCode <= 57){
        translatedKeycodeStructure.keycode = keyCode;
        translatedKeycodeStructure.modifier = 0x01;
    }
    
    //Letters lowercase
    if (keyCode >= 97 && keyCode <= 122){
        translatedKeycodeStructure.keycode = keyCode - 32;
    }
    
    //Other keycode translation, don't hesitate to contribute to the list if you know more keycodes... :)
    switch (keyCode){
        case 32 : // Space
            translatedKeycodeStructure.keycode = 0x20; //Confirmed : Space
            translatedKeycodeStructure.modifier = 0;
            break;
        case 45 : // -
            translatedKeycodeStructure.keycode = 0x6d; //Confirmed : -
            translatedKeycodeStructure.modifier = 0x01;
            break;
        case 47 : // /
            translatedKeycodeStructure.keycode = 0xbf; //Confirmed : /
            translatedKeycodeStructure.modifier = 0x01;
            break;
        case 58 :
            break;
        case 59 : // ;
            translatedKeycodeStructure.keycode = 0xbe; //Confirmed : ;
            translatedKeycodeStructure.modifier = 0;
            break;
        case 40 :
            break;
        case 41 : // )
            translatedKeycodeStructure.keycode = 0xdb; //Confirmed : )
            translatedKeycodeStructure.modifier = 0;
            break;
        case 8364 :
            break;
        case 38 :
            break;
        case 64 :
            break;
        case 34 :
            break;
        case 46 : // .
            translatedKeycodeStructure.keycode = 0xbe; //Confirmed : .
            translatedKeycodeStructure.modifier = 0x01;
            break;
        case 44 :
            break;
        case 63 :
            break;
        case 33 :
            break;
        case 39 :
            break;
        case 91 :
            break;
        case 93 :
            break;
        case 123 :
            break;
        case 125 :
            break;
        case 35 :
            break;
        case 37 :
            break;
        case 94 :
            break;
        case 42 :
            break;
        case 43 :
            break;
        case 61 :
            break;
        case 95 :
            break;
        case 92 :
            break;
        case 124 :
            break;
        case 126 :
            break;
        case 60 :
            break;
        case 62 :
            break;
        case 36 :
            break;
        case 163 :
            break;
        case 165 :
            break;
        case 8226 :
            break;
    }
    
    //Return the original keycode if not found in the previous list
    /*if (translatedKeycodeStructure.keycode == 0){
        translatedKeycodeStructure.keycode = keyCode;
    }*/
    
    return translatedKeycodeStructure;
}
