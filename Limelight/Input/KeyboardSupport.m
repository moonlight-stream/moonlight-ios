//
//  KeyboardSupport.m
//  Moonlight
//
//  Created by Diego Waxemberg on 8/25/18.
//  Copyright © 2018 Moonlight Game Streaming Project. All rights reserved.
//

#import "KeyboardSupport.h"
#include <Limelight.h>

@implementation KeyboardSupport

+ (BOOL)sendKeyEventForPress:(UIPress*)press down:(BOOL)down API_AVAILABLE(ios(13.4)) {
    if (press.key != nil) {
        return [KeyboardSupport sendKeyEvent:press.key down:down];
    }
    else {
        short keyCode;

        switch (press.type) {
            case UIPressTypeUpArrow:
                keyCode = 0x26;
                break;
            case UIPressTypeDownArrow:
                keyCode = 0x28;
                break;
            case UIPressTypeLeftArrow:
                keyCode = 0x25;
                break;
            case UIPressTypeRightArrow:
                keyCode = 0x27;
                break;
            default:
                // Unhandled press type
                return NO;
        }
        
        LiSendKeyboardEvent(0x8000 | keyCode,
                            down ? KEY_ACTION_DOWN : KEY_ACTION_UP,
                            0);
        
        return YES;
    }
}

+ (BOOL)sendKeyEvent:(UIKey*)key down:(BOOL)down API_AVAILABLE(ios(13.4)) {
    char modifierFlags = 0;
    short keyCode = 0;
    
    if (key.modifierFlags & UIKeyModifierShift) {
        modifierFlags |= MODIFIER_SHIFT;
    }
    if (key.modifierFlags & UIKeyModifierAlternate) {
        modifierFlags |= MODIFIER_ALT;
    }
    if (key.modifierFlags & UIKeyModifierControl) {
        modifierFlags |= MODIFIER_CTRL;
    }
    if (key.modifierFlags & UIKeyModifierCommand) {
        modifierFlags |= MODIFIER_META;
    }
    
    // This converts UIKeyboardHIDUsage values to Win32 VK_* values
    // https://docs.microsoft.com/en-us/windows/win32/inputdev/virtual-key-codes
    if (key.keyCode >= UIKeyboardHIDUsageKeyboardA &&
        key.keyCode <= UIKeyboardHIDUsageKeyboardZ) {
        keyCode = (key.keyCode - UIKeyboardHIDUsageKeyboardA) + 0x41;
    }
    else if (key.keyCode == UIKeyboardHIDUsageKeyboard0) {
        // This key is at the beginning of the VK_ range but the end
        // of the UIKeyboardHIDUsageKeyboard range.
        keyCode = 0x30;
    }
    else if (key.keyCode >= UIKeyboardHIDUsageKeyboard1 &&
             key.keyCode <= UIKeyboardHIDUsageKeyboard9) {
        keyCode = (key.keyCode - UIKeyboardHIDUsageKeyboard1) + 0x31;
    }
    else if (key.keyCode == UIKeyboardHIDUsageKeypad0) {
        // This key is at the beginning of the VK_ range but the end
        // of the UIKeyboardHIDUsageKeypad range.
        keyCode = 0x60;
    }
    else if (key.keyCode >= UIKeyboardHIDUsageKeypad1 &&
             key.keyCode <= UIKeyboardHIDUsageKeypad9) {
        keyCode = (key.keyCode - UIKeyboardHIDUsageKeypad1) + 0x61;
    }
    else if (key.keyCode >= UIKeyboardHIDUsageKeyboardF1 &&
             key.keyCode <= UIKeyboardHIDUsageKeyboardF12) {
        keyCode = (key.keyCode - UIKeyboardHIDUsageKeyboardF1) + 0x70;
    }
    else if (key.keyCode >= UIKeyboardHIDUsageKeyboardF13 &&
             key.keyCode <= UIKeyboardHIDUsageKeyboardF24) {
        keyCode = (key.keyCode - UIKeyboardHIDUsageKeyboardF13) + 0x7C;
    }
    else {
        switch (key.keyCode) {
            case UIKeyboardHIDUsageKeyboardReturnOrEnter:
                keyCode = 0x0D;
                break;
            case UIKeyboardHIDUsageKeyboardEscape:
                keyCode = 0x1B;
                break;
            case UIKeyboardHIDUsageKeyboardDeleteOrBackspace:
                keyCode = 0x08;
                break;
            case UIKeyboardHIDUsageKeyboardTab:
                keyCode = 0x09;
                break;
            case UIKeyboardHIDUsageKeyboardSpacebar:
                keyCode = 0x20;
                break;
            case UIKeyboardHIDUsageKeyboardHyphen:
                keyCode = 0xBD;
                break;
            case UIKeyboardHIDUsageKeyboardEqualSign:
                keyCode = 0xBB;
                break;
            case UIKeyboardHIDUsageKeyboardOpenBracket:
                keyCode = 0xDB;
                break;
            case UIKeyboardHIDUsageKeyboardCloseBracket:
                keyCode = 0xDD;
                break;
            case UIKeyboardHIDUsageKeyboardBackslash:
                keyCode = 0xDC;
                break;
            case UIKeyboardHIDUsageKeyboardSemicolon:
                keyCode = 0xBA;
                break;
            case UIKeyboardHIDUsageKeyboardQuote:
                keyCode = 0xDE;
                break;
            case UIKeyboardHIDUsageKeyboardGraveAccentAndTilde:
                keyCode = 0xC0;
                break;
            case UIKeyboardHIDUsageKeyboardComma:
                keyCode = 0xBC;
                break;
            case UIKeyboardHIDUsageKeyboardPeriod:
                keyCode = 0xBE;
                break;
            case UIKeyboardHIDUsageKeyboardSlash:
                keyCode = 0xBF;
                break;
            case UIKeyboardHIDUsageKeyboardCapsLock:
                keyCode = 0x14;
                break;
            case UIKeyboardHIDUsageKeyboardPrintScreen:
                keyCode = 0x2A;
                break;
            case UIKeyboardHIDUsageKeyboardScrollLock:
                keyCode = 0x91;
                break;
            case UIKeyboardHIDUsageKeyboardPause:
                keyCode = 0x13;
                break;
            case UIKeyboardHIDUsageKeyboardInsert:
                keyCode = 0x2D;
                break;
            case UIKeyboardHIDUsageKeyboardHome:
                keyCode = 0x24;
                break;
            case UIKeyboardHIDUsageKeyboardPageUp:
                keyCode = 0x21;
                break;
            case UIKeyboardHIDUsageKeyboardDeleteForward:
                keyCode = 0x2E;
                break;
            case UIKeyboardHIDUsageKeyboardEnd:
                keyCode = 0x23;
                break;
            case UIKeyboardHIDUsageKeyboardPageDown:
                keyCode = 0x22;
                break;
            case UIKeyboardHIDUsageKeyboardRightArrow:
                keyCode = 0x27;
                break;
            case UIKeyboardHIDUsageKeyboardLeftArrow:
                keyCode = 0x25;
                break;
            case UIKeyboardHIDUsageKeyboardDownArrow:
                keyCode = 0x28;
                break;
            case UIKeyboardHIDUsageKeyboardUpArrow:
                keyCode = 0x26;
                break;
            case UIKeyboardHIDUsageKeypadNumLock:
                keyCode = 0x90;
                break;
            case UIKeyboardHIDUsageKeypadSlash:
                keyCode = 0x6F;
                break;
            case UIKeyboardHIDUsageKeypadAsterisk:
                keyCode = 0x6A;
                break;
            case UIKeyboardHIDUsageKeypadHyphen:
                keyCode = 0x6D;
                break;
            case UIKeyboardHIDUsageKeypadPlus:
                keyCode = 0x6B;
                break;
            case UIKeyboardHIDUsageKeypadEnter:
                keyCode = 0x0D;
                break;
            case UIKeyboardHIDUsageKeypadPeriod:
                keyCode = 0x6E;
                break;
            case UIKeyboardHIDUsageKeyboardNonUSBackslash:
                keyCode = 0xE2;
                break;
            case UIKeyboardHIDUsageKeypadComma:
                keyCode = 0x6C;
                break;
            case UIKeyboardHIDUsageKeyboardCancel:
                keyCode = 0x03;
                break;
            case UIKeyboardHIDUsageKeyboardClear:
                keyCode = 0x0C;
                break;
            case UIKeyboardHIDUsageKeyboardCrSelOrProps:
                keyCode = 0xF7;
                break;
            case UIKeyboardHIDUsageKeyboardExSel:
                keyCode = 0xF8;
                break;
            case UIKeyboardHIDUsageKeyboardLeftGUI:
                keyCode = 0x5B;
                break;
            case UIKeyboardHIDUsageKeyboardLeftControl:
                keyCode = 0xA2;
                break;
            case UIKeyboardHIDUsageKeyboardLeftShift:
                keyCode = 0xA0;
                break;
            case UIKeyboardHIDUsageKeyboardLeftAlt:
                keyCode = 0xA4;
                break;
            case UIKeyboardHIDUsageKeyboardRightGUI:
                keyCode = 0x5C;
                break;
            case UIKeyboardHIDUsageKeyboardRightControl:
                keyCode = 0xA3;
                break;
            case UIKeyboardHIDUsageKeyboardRightShift:
                keyCode = 0xA1;
                break;
            case UIKeyboardHIDUsageKeyboardRightAlt:
                keyCode = 0xA5;
                break;
            case 669: // This value corresponds to the "Globe" or "Language" key on most Apple branded iPad keyboards.
                keyCode = 0x1B; // This value corresponds to "Escape", which is missing from most Apple branded iPad keyboards.
                break;
            default:
                NSLog(@"Unhandled HID usage: %lu", (unsigned long)key.keyCode);
                assert(0);
                return false;
        }
    }
    
    LiSendKeyboardEvent(0x8000 | keyCode,
                        down ? KEY_ACTION_DOWN : KEY_ACTION_UP,
                        modifierFlags);
    return true;
}

+ (struct KeyEvent)translateKeyEvent:(unichar)inputChar withModifierFlags:(UIKeyModifierFlags)modifierFlags {
    struct KeyEvent event;
    event.keycode = 0;
    event.modifier = 0;
    event.modifierKeycode = 0;
    
    switch (modifierFlags) {
        case UIKeyModifierAlphaShift:
        case UIKeyModifierShift:
            [KeyboardSupport addShiftModifier:&event];
            break;
        case UIKeyModifierControl:
            [KeyboardSupport addControlModifier:&event];
            break;
        case UIKeyModifierCommand:
            [KeyboardSupport addMetaModifier:&event];
            break;
        case UIKeyModifierAlternate:
            [KeyboardSupport addAltModifier:&event];
            break;
        case UIKeyModifierNumericPad:
            break;
    }
    if (inputChar >= 0x30 && inputChar <= 0x39) {
        // Numbers 0-9
        event.keycode = inputChar;
    } else if (inputChar >= 0x41 && inputChar <= 0x5A) {
        // Capital letters
        event.keycode = inputChar;
        [KeyboardSupport addShiftModifier:&event];
    } else if (inputChar >= 0x61 && inputChar <= 0x7A) {
        // Lower case letters
        event.keycode = inputChar - (0x61 - 0x41);
    } switch (inputChar) {
        case ' ': // Spacebar
            event.keycode = 0x20;
            break;
        case '-': // Hyphen '-'
            event.keycode = 0xBD;
            break;
        case '/': // Forward slash '/'
            event.keycode = 0xBF;
            break;
        case ':': // Colon ':'
            event.keycode = 0xBA;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case ';': // Semi-colon ';'
            event.keycode = 0xBA;
            break;
        case '(': // Open parenthesis '('
            event.keycode = 0x39; // '9'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case ')': // Close parenthesis ')'
            event.keycode = 0x30; // '0'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '$': // Dollar sign '$'
            event.keycode = 0x34; // '4'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '&': // Ampresand '&'
            event.keycode = 0x37; // '7'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '@': // At-sign '@'
            event.keycode = 0x32; // '2'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '"':
            event.keycode = 0xDE;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '\'':
            event.keycode = 0xDE;
            break;
        case '!':
            event.keycode = 0x31; // '1'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '?':
            event.keycode = 0xBF; // '/'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case ',':
            event.keycode = 0xBC;
            break;
        case '<':
            event.keycode = 0xBC;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '.':
            event.keycode = 0xBE;
            break;
        case '>':
            event.keycode = 0xBE;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '[':
            event.keycode = 0xDB;
            break;
        case ']':
            event.keycode = 0xDD;
            break;
        case '{':
            event.keycode = 0xDB;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '}':
            event.keycode = 0xDD;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '#':
            event.keycode = 0x33; // '3'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '%':
            event.keycode = 0x35; // '5'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '^':
            event.keycode = 0x36; // '6'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '*':
            event.keycode = 0x38; // '8'
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '+':
            event.keycode = 0xBB;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '=':
            event.keycode = 0xBB;
            break;
        case '_':
            event.keycode = 0xBD;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '\\':
            event.keycode = 0xDC;
            break;
        case '|':
            event.keycode = 0xDC;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '~':
            event.keycode = 0xC0;
            [KeyboardSupport addShiftModifier:&event];
            break;
        case '`':
            event.keycode = 0xC0;
            break;
        case '\t':
            event.keycode = 0x09;
            break;
        default:
            break;
    }
 
    return event;
}

+ (void) addShiftModifier:(struct KeyEvent*)event {
    event->modifier = MODIFIER_SHIFT;
    event->modifierKeycode = 0x10;
}

+ (void) addControlModifier:(struct KeyEvent*)event {
    event->modifier = MODIFIER_CTRL;
    event->modifierKeycode = 0x11;
}

+ (void) addMetaModifier:(struct KeyEvent*)event {
    event->modifier = MODIFIER_META;
    event->modifierKeycode = 0x5B;
}

+ (void) addAltModifier:(struct KeyEvent*)event {
    event->modifier = MODIFIER_ALT;
    event->modifierKeycode = 0x12;
}

@end
