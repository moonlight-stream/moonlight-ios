//
//  StreamView.m
//  Moonlight macOS
//
//  Created by Felix Kratz on 10.3.18.
//  Copyright (c) 2018 Felix Kratz. All rights reserved.
//

#import "StreamView.h"
#include <Limelight.h>
#import "DataManager.h"
#include <ApplicationServices/ApplicationServices.h>
#include "keyboardTranslation.h"
#import "NetworkTraffic.h"

@implementation StreamView {
    bool isDragging;
    bool statsDisplayed;
    unsigned long lastNetworkDown;
    unsigned long lastNetworkUp;
    unsigned int frameCount;
    NSTrackingArea* _trackingArea;
    NSTextField* _textFieldIncomingBitrate;
    NSTextField* _textFieldOutgoingBitrate;
    NSTextField* _textFieldCodec;
    NSTextField* _textFieldFramerate;
    NSTextField* _stageLabel;
    
    NSTimer* _statTimer;
}

- (void) updateTrackingAreas {
    if (_trackingArea != nil) {
        [self removeTrackingArea:_trackingArea];
    }
    NSTrackingAreaOptions options = (NSTrackingActiveAlways | NSTrackingInVisibleRect |
                                     NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved);
    
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds]
                                                        options:options
                                                          owner:self
                                                       userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

-(void)mouseDragged:(NSEvent *)event {
    if (isDragging) {
        [self mouseMoved:event];
    }
    else {
        [self mouseDown:event];
        isDragging = true;
    }
}

-(void)rightMouseDragged:(NSEvent *)event
{
    if (isDragging) {
        [self mouseMoved:event];
    }
    else {
        [self rightMouseDown:event];
        isDragging = true;
    }
}

-(void)scrollWheel:(NSEvent *)event {
    LiSendScrollEvent(event.scrollingDeltaY);
}

- (void)mouseDown:(NSEvent *)mouseEvent {
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_LEFT);
}

- (void)mouseUp:(NSEvent *)mouseEvent {
    isDragging = false;
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_LEFT);
}

- (void)rightMouseUp:(NSEvent *)mouseEvent {
    isDragging = false;
    LiSendMouseButtonEvent(BUTTON_ACTION_RELEASE, BUTTON_RIGHT);
}

- (void)rightMouseDown:(NSEvent *)mouseEvent {
    LiSendMouseButtonEvent(BUTTON_ACTION_PRESS, BUTTON_RIGHT);
}

- (void)mouseMoved:(NSEvent *)mouseEvent {
    LiSendMouseMoveEvent(mouseEvent.deltaX, mouseEvent.deltaY);
}

-(void)keyDown:(NSEvent *)event {
    unsigned char keyChar = keyCharFromKeyCode(event.keyCode);
    NSLog(@"DOWN: KeyCode: %hu, keyChar: %d, keyModifier: %lu \n", event.keyCode, keyChar, event.modifierFlags);
    
    LiSendKeyboardEvent(keyChar, KEY_ACTION_DOWN, modifierFlagForKeyModifier(event.modifierFlags));
    
    // This is the key combo for the stream overlay
    if (event.modifierFlags & kCGEventFlagMaskCommand && event.keyCode == kVK_ANSI_I) {
        [self toggleStats];
    }
}

-(void)keyUp:(NSEvent *)event {
    unsigned char keyChar = keyCharFromKeyCode(event.keyCode);
    NSLog(@"UP: KeyChar: %d \n‚", keyChar);
    LiSendKeyboardEvent(keyChar, KEY_ACTION_UP, modifierFlagForKeyModifier(event.modifierFlags));
}

- (void)flagsChanged:(NSEvent *)event {
    unsigned char keyChar = keyCodeFromModifierKey(event.modifierFlags);
    if(keyChar) {
        NSLog(@"DOWN: FlagChanged: %hhu \n", keyChar);
        LiSendKeyboardEvent(keyChar, KEY_ACTION_DOWN, 0x00);
    }
    else {
        LiSendKeyboardEvent(58, KEY_ACTION_UP, 0x00);
    }
}

- (void)setupTextField:(NSTextField*)textField {
    textField.drawsBackground = false;
    textField.bordered = false;
    textField.editable = false;
    textField.alignment = NSTextAlignmentLeft;
    textField.textColor = [NSColor whiteColor];
    [self addSubview:textField];
}

- (void)initStats {
    _textFieldCodec = [[NSTextField alloc] initWithFrame:NSMakeRect(5, NSScreen.mainScreen.frame.size.height - 22, 200, 17)];
    _textFieldIncomingBitrate = [[NSTextField alloc] initWithFrame:NSMakeRect(5, 5, 250, 17)];
    _textFieldOutgoingBitrate = [[NSTextField alloc] initWithFrame:NSMakeRect(5, 5 + 20, 250, 17)];
    _textFieldFramerate = [[NSTextField alloc] initWithFrame:NSMakeRect(NSScreen.mainScreen.frame.size.width - 50, NSScreen.mainScreen.frame.size.height - 22, 50, 17)];
    
    [self setupTextField:_textFieldOutgoingBitrate];
    [self setupTextField:_textFieldIncomingBitrate];
    [self setupTextField:_textFieldCodec];
    [self setupTextField:_textFieldFramerate];
}

- (void)initStageLabel {
    _stageLabel = [[NSTextField alloc] initWithFrame:NSMakeRect(NSScreen.mainScreen.frame.size.width/2 - 100, NSScreen.mainScreen.frame.size.height/2 - 8, 200, 17)];
    _stageLabel.drawsBackground = false;
    _stageLabel.bordered = false;
    _stageLabel.alignment = NSTextAlignmentCenter;
    _stageLabel.textColor = [NSColor blackColor];
    
    [self addSubview:_stageLabel];
}

- (void)statTimerTick {
    _textFieldFramerate.stringValue = [NSString stringWithFormat:@"%i fps", frameCount];
    frameCount = 0;
    
    unsigned long currentNetworkDown = getBytesDown();
    _textFieldIncomingBitrate.stringValue = [NSString stringWithFormat:@"Incoming Bitrate (System): %lu kbps", (currentNetworkDown - lastNetworkDown)*8 / 1000];
    lastNetworkDown = currentNetworkDown;
    
    unsigned long currentNetworkUp = getBytesUp();
    _textFieldOutgoingBitrate.stringValue = [NSString stringWithFormat:@"Outgoing Bitrate (System): %lu kbps", (currentNetworkUp - lastNetworkUp)*8 / 1000];
    lastNetworkUp = currentNetworkUp;
}

- (void)toggleStats {
    statsDisplayed = !statsDisplayed;
    if (statsDisplayed) {
        frameCount = 0;
        if (_textFieldIncomingBitrate == nil || _textFieldCodec == nil || _textFieldOutgoingBitrate == nil || _textFieldFramerate == nil) {
            [self initStats];
        }
        _statTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(statTimerTick) userInfo:nil repeats:true];
        NSLog(@"display stats");
        if (_codec == 1) {
            _textFieldCodec.stringValue = @"Codec: H264";
        }
        else if (_codec == 256) {
            _textFieldCodec.stringValue = @"Codec: HEVC/H265";
        }
        else {
            _textFieldCodec.stringValue = @"Codec: Unknown";
        }
        [self statTimerTick];
    }
    else    {
        [_statTimer invalidate];
        _textFieldCodec.stringValue = @"";
        _textFieldIncomingBitrate.stringValue = @"";
        _textFieldOutgoingBitrate.stringValue = @"";
        _textFieldFramerate.stringValue = @"";
    }
}

- (void)drawMessage:(NSString*)message {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_stageLabel == nil) {
            [self initStageLabel];
        }
        self->_stageLabel.stringValue = message;
    });
}

- (void)newFrame {
    frameCount++;
}

- (BOOL)acceptsFirstResponder {
    return YES;
}
@end
