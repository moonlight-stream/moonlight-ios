//
//  ControllerSupport.m
//  Moonlight macOS
//
//  Created by Felix Kratz on 15.03.18.
//  Copyright © 2018 Felix Kratz. All rights reserved.
//

#import "ControllerSupport.h"
#import "DataManager.h"
#include "Limelight.h"
#include "Gamepad.h"

@class Controller;

@implementation ControllerSupport {
    NSLock *_controllerStreamLock;
    NSMutableDictionary *_controllers;
    char _controllerNumbers;
    Controller* _controller;
}

-(void) updateButtonFlags:(Controller*)controller flags:(int)flags
{
    @synchronized(controller) {
        controller.lastButtonFlags = flags;
    }
}

-(void) setButtonFlag:(Controller*)controller flags:(int)flags
{
    @synchronized(controller) {
        controller.lastButtonFlags |= flags;
    }
}

-(void) clearButtonFlag:(Controller*)controller flags:(int)flags
{
    @synchronized(controller) {
        controller.lastButtonFlags &= ~flags;
    }
}

-(void) updateFinished:(Controller*)controller
{
    _controllerNumbers = 0;
     _controllerNumbers |= (1 << 0);
    controller.playerIndex = 0;
    [_controllerStreamLock lock];
    @synchronized(controller) {
        LiSendMultiControllerEvent(controller.playerIndex, _controllerNumbers | 0, controller.lastButtonFlags, controller.lastLeftTrigger, controller.lastRightTrigger, controller.lastLeftStickX, controller.lastLeftStickY, controller.lastRightStickX, controller.lastRightStickY);
    }
    [_controllerStreamLock unlock];
}

-(id) init
{
    self = [super init];
    return self;

}

@end
