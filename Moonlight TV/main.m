//
//  main.m
//  Moonlight TV
//
//  Created by Diego Waxemberg on 8/25/18.
//  Copyright © 2018 Moonlight Game Streaming Project. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

#define SDL_MAIN_HANDLED
#import <SDL.h>

int main(int argc, char * argv[]) {
    @autoreleasepool {
        SDL_SetMainReady();
        return UIApplicationMain(argc, argv, nil, NSStringFromClass([AppDelegate class]));
    }
}
