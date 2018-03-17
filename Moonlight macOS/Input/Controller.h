//
//  Controller.h
//  Moonlight macOS
//
//  Created by Felix Kratz on 15.03.18.
//  Copyright © 2018 Felix Kratz. All rights reserved.
//

#ifndef Controller_h
#define Controller_h

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface Controller : NSObject

@property int playerIndex;
@property int lastButtonFlags;
@property int emulatingButtonFlags;
@property char lastLeftTrigger;
@property char lastRightTrigger;
@property short lastLeftStickX;
@property short lastLeftStickY;
@property short lastRightStickX;
@property short lastRightStickY;

@end

#endif /* Controller_h */
