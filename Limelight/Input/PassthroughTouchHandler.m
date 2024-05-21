//
//  PassthroughTouchHandler.m
//  Moonlight
//
//  Created by ZigZagT on 5/20/2024.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import "PassthroughTouchHandler.h"

#include <Limelight.h>

@implementation PassthroughTouchHandler {
    StreamView* view;
}

- (id)initWithView:(StreamView*)view {
    self = [self init];
    self->view = view;
    return self;
}

- (int)sendTouchEvent:(UITouch*)touch withType:(uint8_t)eventType {
    CGPoint location = [self->view adjustCoordinatesForVideoArea:[touch locationInView:self->view]];
    CGSize videoSize = [self->view getVideoAreaSize];
    return LiSendTouchEvent(
        eventType,
        (uint32_t) (uintptr_t) touch,
        location.x / videoSize.width,
        location.y / videoSize.height,
        0,
        0,
        0,
        LI_ROT_UNKNOWN
    );
}



- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) {
        [self sendTouchEvent:touch withType:LI_TOUCH_EVENT_DOWN];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) {
        [self sendTouchEvent:touch withType:LI_TOUCH_EVENT_MOVE];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) {
        [self sendTouchEvent:touch withType:LI_TOUCH_EVENT_UP];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) {
        [self sendTouchEvent:touch withType:LI_TOUCH_EVENT_CANCEL];
    }
}

@end
