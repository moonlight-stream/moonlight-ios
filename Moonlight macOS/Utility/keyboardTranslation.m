//
//  keyboardTranslation.m
//  Moonlight macOS
//
//  Created by Felix Kratz on 10.03.18.
//  Copyright © 2018 Felix Kratz. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "keyboardTranslation.h"
#import <Limelight.h>

CGKeyCode modifierKeyFromEvent(int keyModifier) {
    switch (keyModifier) {
        case 131330:
            return 0xA0; //LSHIFT
            //case 131332:              TODO: This will lockup the modifiers
        //    return 0xA1; //RSHIFT
        case 524576:
            return 0xA4; //LALT
        //case 524608:                  TODO: This will lockup the modifiers
        //    return 0xA5; //RALT
        case 262401:
            return 0xA2; //LCTRL

        default:
            return 0x00;
    }
}

char keyModifierFromEvent(int keyModifier)
{
    switch (keyModifier) {
        case 131330:
            return MODIFIER_SHIFT; //LSHIFT
        case 131332:
            return MODIFIER_SHIFT; //RSHIFT
        case 524576:
            return MODIFIER_ALT; //LALT
        case 524608:
            return MODIFIER_ALT; //RALT
        case 262401:
            return MODIFIER_CTRL; //LCTRL
            
        default:
            return 0x00;
    }
}


CGKeyCode keyCharFromKeyCode(CGKeyCode keyCode) {
    switch (keyCode)
    {
        case 0: return 'A';
        case 1: return 'S';
        case 2: return 'D';
        case 3: return 'F';
        case 4: return 'H';
        case 5: return 'G';
        case 6: return 'Y';
        case 7: return 'X';
        case 8: return 'C';
        case 9: return 'V';
        case 11: return 'B';
        case 12: return 'Q';
        case 13: return 'W';
        case 14: return 'E';
        case 15: return 'R';
        case 16: return 'Z';
        case 17: return 'T';
        case 18: return '1';
        case 19: return '2';
        case 20: return '3';
        case 21: return '4';
        case 22: return '6';
        case 23: return '5';
        case 24: return '=';
        case 25: return '9';
        case 26: return '7';
        case 27: return '-';
        case 28: return '8';
        case 29: return '0';
        case 30: return ']';
        case 31: return 'O';
        case 32: return 'U';
        case 33: return '[';
        case 34: return 'I';
        case 35: return 'P';
        case 36: return 13; // ENTER
        case 37: return 'L';
        case 38: return 'J';
        case 39: return '\'';
        case 40: return 'K';
        case 41: return ';';
        case 42: return '\\';
        case 43: return 0xBC; //,
        case 44: return 0xBD; //-
        case 45: return 'N';
        case 46: return 'M';
        case 47: return 0xBE; //.
        case 48: return 0x09; // TAB
        case 49: return 32; // SPACE
        case 50: return '`';
        case 51: return 8; //BackSpace
        case 52: return 13; //ENTER
        case 53: return 27; //ESC
        case 65: return '.';
        case 67: return '*';
        case 69: return '+';
        case 71: return 127; //Del
        case 75: return '/';
        case 76: return 13;   // numpad enter
        case 78: return '-';
         /*
        case 81: return @"=";
        case 82: return '0';
        case 83: return '1';
        case 84: return '2';
        case 85: return '3';
        case 86: return @"4";
        case 87: return @"5";
        case 88: return @"6";
        case 89: return @"7";
            
        case 91: return @"8";
        case 92: return @"9";
            
        case 96: return @"F5";
        case 97: return @"F6";
        case 98: return @"F7";
        case 99: return @"F3";
        case 100: return @"F8";
        case 101: return @"F9";
            
        case 103: return @"F11";
            
        case 105: return @"F13";
            
        case 107: return @"F14";
            
        case 109: return @"F10";
            
        case 111: return @"F12";
            
        case 113: return @"F15";
        case 114: return @"HELP";
        case 115: return @"HOME";
        case 116: return @"PGUP";
        case 117: return 8;  // full keyboard right side numberpad
        case 118: return @"F4";
        case 119: return @"END";
        case 120: return @"F2";
        case 121: return @"PGDN";
        case 122: return @"F1";
          */
        case 123: return 0x25; //LEFT
        case 124: return 0x27; //RIGHT
        case 125: return 0x28; //DOWN
        case 126: return 0x26; //UP
        default:
            return 0;
    }
}
