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
    bool activateCoordSelector;
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


- (void)sendTouchEvent:(UITouch*)touch withTouchtype:(uint8_t)touchType{
    CGPoint targetCoords;
    if(activateCoordSelector && touch.phase == UITouchPhaseMoved) targetCoords = [NativeTouchPointer selectCoordsFor:touch]; // coordinates of touch pointer replaced to relative ones here.
    else targetCoords = [touch locationInView:streamView];
    CGPoint location = [streamView adjustCoordinatesForVideoArea:targetCoords];
    CGSize videoSize = [streamView getVideoAreaSize];
    LiSendTouchEvent(touchType,[NativeTouchPointer retrievePointerIdFromDict:touch],location.x / videoSize.width, location.y / videoSize.height,(touch.force / touch.maximumPossibleForce) / sin(touch.altitudeAngle),0.0f, 0.0f,[streamView getRotationFromAzimuthAngle:[touch azimuthAngleInView:streamView]]);
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches){
        [NativeTouchPointer populatePointerId:touch]; //generate & populate pointerId
        if(activateCoordSelector) [NativeTouchPointer populatePointerObjIntoDict:touch];
        [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_DOWN];
    }
    return;
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches){
        if(activateCoordSelector) [NativeTouchPointer updatePointerObjInDict:touch];
        [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_MOVE];
    }
    return;
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches){
        [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_UP]; //send touch event before remove pointerId
        [NativeTouchPointer removePointerId:touch]; //then remove pointerId
        if(activateCoordSelector) [NativeTouchPointer removePointerObjFromDict:touch];
    }
    return;
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches){
        [self sendTouchEvent:touch withTouchtype:LI_TOUCH_EVENT_UP]; //send touch event before remove pointerId
        [NativeTouchPointer removePointerId:touch]; //then remove pointerId
        if(activateCoordSelector) [NativeTouchPointer removePointerObjFromDict:touch];
    }
}


@end
