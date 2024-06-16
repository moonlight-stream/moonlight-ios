//
//  NativeTouchHandler.m
//  Moonlight
//
//  Created by ZWM on 2024/6/16.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NativeTouchHandler.h"
#import "NativeTouchPointer.h"
#import "StreamView.h"
#import "DataManager.h"

#include <Limelight.h>



@implementation NativeTouchHandler {
    StreamView* streamView;
    TemporarySettings* currentSettings;
    BOOL activateCoordSelector;
}


- (id)initWith:(StreamView*)view and:(TemporarySettings*)settings{
    self = [self init];
    self->streamView = view;
    self->currentSettings = settings;
    self->activateCoordSelector = currentSettings.pointerVelocityModeDivider.floatValue != 1.0;
    [NativeTouchPointer setPointerVelocityDivider:settings.pointerVelocityModeDivider.floatValue];
    [NativeTouchPointer setPointerVelocityFactor:settings.touchPointerVelocityFactor.floatValue];
    [NativeTouchPointer initContextWith:streamView];
    
    return self;
}


- (void)sendTouchEvent:(UITouch*)event touchType:(uint8_t)touchType{
    CGPoint targetCoords;
    if(activateCoordSelector && event.phase == UITouchPhaseMoved) targetCoords = [NativeTouchPointer selectCoordsFor:event]; // coordinates of touch pointer replaced to relative ones here.
    else targetCoords = [event locationInView:streamView];
    CGPoint location = [streamView adjustCoordinatesForVideoArea:targetCoords];
    CGSize videoSize = [streamView getVideoAreaSize];
    LiSendTouchEvent(touchType,[NativeTouchPointer retrievePointerIdFromDict:event],location.x / videoSize.width, location.y / videoSize.height,(event.force / event.maximumPossibleForce) / sin(event.altitudeAngle),0.0f, 0.0f,[streamView getRotationFromAzimuthAngle:[event azimuthAngleInView:streamView]]);
}


- (void)handleUITouch:(UITouch*)event index:(int)index{
    uint8_t type;
// NSLog(@"handleUITouch %ld,%d",(long)event.phase,(uint32_t)event);
//#define LI_TOUCH_EVENT_HOVER       0x00
//#define LI_TOUCH_EVENT_DOWN        0x01
//#define LI_TOUCH_EVENT_UP          0x02
//#define LI_TOUCH_EVENT_MOVE        0x03
//#define LI_TOUCH_EVENT_CANCEL      0x04
//#define LI_TOUCH_EVENT_BUTTON_ONLY 0x05
//#define LI_TOUCH_EVENT_HOVER_LEAVE 0x06
//#define LI_TOUCH_EVENT_CANCEL_ALL  0x07
//#define LI_ROT_UNKNOWN 0xFFFF
    
//    UITouchPhaseBegan,             // whenever a finger touches the surface.
//    UITouchPhaseMoved,             // whenever a finger moves on the surface.
//    UITouchPhaseStationary,        // whenever a finger is touching the surface but hasn't moved since the previous event.
//    UITouchPhaseEnded,             // whenever a finger leaves the surface.
//    UITouchPhaseCancelled,         // whenever a touch doesn't end but we need to stop tracking (e.g. putting device to face)
//    UITouchPhaseRegionEntered   API_AVAILABLE(ios(13.4), tvos(13.4)) API_UNAVAILABLE(watchos),  // whenever a touch is entering the region of a user interface
//    UITouchPhaseRegionMoved     API_AVAILABLE(ios(13.4), tvos(13.4)) API_UNAVAILABLE(watchos),  // when a touch is inside the region of a user interface, but hasn’t yet made contact or left the region
//    UITouchPhaseRegionExited    API_AVAILABLE(ios(13.4), tvos(13.4))
    
    switch (event.phase) {
        case UITouchPhaseBegan://touchBegan
            type = LI_TOUCH_EVENT_DOWN;
            [NativeTouchPointer populatePointerId:event]; //generate & populate pointerId
            if(activateCoordSelector) [NativeTouchPointer populatePointerObjIntoDict:event];
            break;
        case UITouchPhaseMoved://touchMoved
        case UITouchPhaseStationary:
            type = LI_TOUCH_EVENT_MOVE;
            if(activateCoordSelector) [NativeTouchPointer updatePointerObjInDict:event];
            break;
        case UITouchPhaseEnded://touchEnded
            type = LI_TOUCH_EVENT_UP;
            [self sendTouchEvent:event touchType:type]; //send touch event first
            [NativeTouchPointer removePointerId:event]; //then remove pointerId
            if(activateCoordSelector) [NativeTouchPointer removePointerObjFromDict:event];
            return;
        case UITouchPhaseCancelled://touchCancelled
            type = LI_TOUCH_EVENT_CANCEL;
            [self sendTouchEvent:event touchType:type]; //send touch event first
            [NativeTouchPointer removePointerId:event]; //then remove pointerId
            if(activateCoordSelector) [NativeTouchPointer removePointerObjFromDict:event];
            return;
        case UITouchPhaseRegionEntered:
        case UITouchPhaseRegionMoved:
            type = LI_TOUCH_EVENT_HOVER;
            break;
        default:
            return;
    }
    [self sendTouchEvent:event touchType:type];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
        for (UITouch* touch in touches) [self handleUITouch:touch index:0];
        return;
    }

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) [self handleUITouch:touch index:0];
    return;
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) [self handleUITouch:touch index:0];
    return;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) [self handleUITouch:touch index:0];// Native touch (absoluteTouch) first!
    return;
}


@end
