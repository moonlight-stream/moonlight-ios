//
//  SceneDelegate.m
//  Moonlight
//
//  Copyright (c) 2026 Moonlight Stream. All rights reserved.
//

#import "SceneDelegate.h"
#import "AppDelegate.h"

@implementation SceneDelegate

// Apps built with the iOS 27 SDK must adopt the UIScene life cycle or UIKit will
// terminate them at launch. UIKit creates our window from the storyboard named in
// the scene manifest in our Info.plist, so we only need to handle quick actions.

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // Handle being launched from a home screen quick action
    UIApplicationShortcutItem* shortcut = connectionOptions.shortcutItem;
    if (shortcut != nil) {
        AppDelegate* appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
        appDelegate.pcUuidToLoad = (NSString*)[shortcut.userInfo objectForKey:@"UUID"];
    }
}

- (void)windowScene:(UIWindowScene *)windowScene performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL succeeded))completionHandler {
    AppDelegate* appDelegate = (AppDelegate*)[UIApplication sharedApplication].delegate;
    appDelegate.pcUuidToLoad = (NSString*)[shortcutItem.userInfo objectForKey:@"UUID"];
    appDelegate.shortcutCompletionHandler = completionHandler;
}

@end
