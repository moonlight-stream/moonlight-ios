//
//  Control.m
//  Moonlight macOS
//
//  Created by Felix Kratz on 15.03.18.
//  Copyright © 2018 Felix Kratz. All rights reserved.
//


#include "Gamepad.h"
#include "Control.h"
#include "Controller.h"
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <math.h>
#import "ControllerSupport.h"
#include "Limelight.h"

#ifdef _MSC_VER
#define snprintf _snprintf
#endif

static bool verbose = true;
Controller* _controller;
ControllerSupport* _controllerSupport;

void onButtonDown(struct Gamepad_device * device, unsigned int buttonID, double timestamp, void * context) {
    if (verbose) {
        switch (buttonID) {
            case 0: //SELECT
                [_controllerSupport setButtonFlag:_controller flags:BACK_FLAG];
                break;
            case 1: //L3
                [_controllerSupport setButtonFlag:_controller flags:LS_CLK_FLAG];
                break;
            case 2: //R3
                [_controllerSupport setButtonFlag:_controller flags:RS_CLK_FLAG];
                break;
            case 3: //START
                [_controllerSupport setButtonFlag:_controller flags:PLAY_FLAG];
                break;
            case 4: //UP
                [_controllerSupport setButtonFlag:_controller flags:UP_FLAG];
                break;
            case 5: //RIGHT
                [_controllerSupport setButtonFlag:_controller flags:RIGHT_FLAG];
                break;
            case 6: //DOWN
                [_controllerSupport setButtonFlag:_controller flags:DOWN_FLAG];
                break;
            case 7: //LEFT
                [_controllerSupport setButtonFlag:_controller flags:LEFT_FLAG];
                break;
            case 10: //LB
                [_controllerSupport setButtonFlag:_controller flags:LB_FLAG];
                break;
            case 11: //RB
                [_controllerSupport setButtonFlag:_controller flags:RB_FLAG];
                break;
            case 12: //Y
                [_controllerSupport setButtonFlag:_controller flags:Y_FLAG];
                break;
            case 13: //B
                [_controllerSupport setButtonFlag:_controller flags:B_FLAG];
                break;
            case 14: //A
                [_controllerSupport setButtonFlag:_controller flags:A_FLAG];
                break;
            case 15: //X
                [_controllerSupport setButtonFlag:_controller flags:X_FLAG];
                break;
                
            default:
                break;
        }
    }
}

void onButtonUp(struct Gamepad_device * device, unsigned int buttonID, double timestamp, void * context) {
    if (verbose) {
        printf("Button");
        switch (buttonID) {
            case 0: //SELECT
                [_controllerSupport clearButtonFlag:_controller flags:BACK_FLAG];
                break;
            case 1: //L3
                [_controllerSupport clearButtonFlag:_controller flags:LS_CLK_FLAG];
                break;
            case 2: //R3
                [_controllerSupport clearButtonFlag:_controller flags:RS_CLK_FLAG];
                break;
            case 3: //START
                [_controllerSupport clearButtonFlag:_controller flags:PLAY_FLAG];
                break;
            case 4: //UP
                [_controllerSupport clearButtonFlag:_controller flags:UP_FLAG];
                break;
            case 5: //RIGHT
                [_controllerSupport clearButtonFlag:_controller flags:RIGHT_FLAG];
                break;
            case 6: //DOWN
                [_controllerSupport clearButtonFlag:_controller flags:DOWN_FLAG];
                break;
            case 7: //LEFT
                [_controllerSupport clearButtonFlag:_controller flags:LEFT_FLAG];
                break;
            case 10: //LB
                [_controllerSupport clearButtonFlag:_controller flags:LB_FLAG];
                break;
            case 11: //RB
                [_controllerSupport clearButtonFlag:_controller flags:RB_FLAG];
                break;
            case 12: //Y
                [_controllerSupport clearButtonFlag:_controller flags:Y_FLAG];
                break;
            case 13: //B
                [_controllerSupport clearButtonFlag:_controller flags:B_FLAG];
                break;
            case 14: //A
                [_controllerSupport clearButtonFlag:_controller flags:A_FLAG];
                break;
            case 15: //X
                [_controllerSupport clearButtonFlag:_controller flags:X_FLAG];
                break;
                
            default:
                break;
        }
        [_controllerSupport updateFinished:_controller];
    }
}

void onAxisMoved(struct Gamepad_device * device, unsigned int axisID, float value, float lastValue, double timestamp, void * context) {
    if (verbose && /*(axisID <= 4) &&*/ fabsf(lastValue - value) > 0.01) {
        switch (axisID) {
            case 0: //y-Axis of Right Stick
                printf("%u", axisID);
                _controller.lastLeftStickX = value * 0X7FFE;
                break;
            case 1: //x-Axis of Left Stick
                printf("%u", axisID);
                _controller.lastLeftStickY = -value * 0X7FFE;
                break;
            case 2: //X-Axis of Right Stick
                printf("%u", axisID);
                _controller.lastRightStickX = value * 0X7FFE;
                break;
            case 3: //Y-Axis of Right Stick
                printf("%u", axisID);
                _controller.lastRightStickY = -value * 0X7FFE;
                break;
            case 14:
                _controller.lastLeftTrigger = value * 0xFF;
                break;
            case 15:
                _controller.lastRightTrigger = value * 0xFF;
                break;
            default:
                break;
        }
        [_controllerSupport updateFinished:_controller];
    }
}

void onDeviceAttached(struct Gamepad_device * device, void * context) {
    if (verbose) {
        printf("Device ID %u attached (vendor = 0x%X; product = 0x%X) with context %p\n", device->deviceID, device->vendorID, device->productID, context);
    }
}

void onDeviceRemoved(struct Gamepad_device * device, void * context) {
    if (verbose) {
        printf("Device ID %u removed with context %p\n", device->deviceID, context);
    }
}

void initGamepad() {
    Gamepad_deviceAttachFunc(onDeviceAttached, NULL);
    Gamepad_deviceRemoveFunc(onDeviceRemoved, NULL);
    Gamepad_buttonDownFunc(onButtonDown, NULL);
    Gamepad_buttonUpFunc(onButtonUp, NULL);
    Gamepad_axisMoveFunc(onAxisMoved, NULL);
    Gamepad_init();
    _controller = [[Controller alloc] init];
    _controllerSupport = [[ControllerSupport alloc] init];

}
