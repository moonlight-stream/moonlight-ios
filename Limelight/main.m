//
//  main.m
//  Moonlight
//
//  Created by Diego Waxemberg on 8/30/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "AppDelegate.h"

#define SDL_MAIN_HANDLED
#import <SDL.h>

int main(int argc, char * argv[])
{
    @autoreleasepool {
        SDL_SetMainReady();
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
