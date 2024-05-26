//
//  DataManager.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "AppDelegate.h"
#import "TemporaryHost.h"
#import "TemporaryApp.h"
#import "TemporarySettings.h"

@interface DataManager : NSObject

- (void) saveSettingsWithBitrate:(NSInteger)bitrate
                       framerate:(NSInteger)framerate
                          height:(NSInteger)height
                           width:(NSInteger)width
                audioConfig:(NSInteger)audioConfig
                onscreenControls:(NSInteger)onscreenControls
            keyboardToggleFingers:(NSInteger)keyboardToggleFingers
             swipeExitScreenEdge:(NSInteger)swipeExitScreenEdge
             swipeToExitDistance:(CGFloat)swipeToExitDistance
       liftStreamViewForKeyboard:(BOOL)liftStreamViewForKeyboard
             showKeyboardToolbar:(BOOL)showKeyboardToolbar
                   optimizeGames:(BOOL)optimizeGames
                 multiController:(BOOL)multiController
                 swapABXYButtons:(BOOL)swapABXYButtons
                       audioOnPC:(BOOL)audioOnPC
                  preferredCodec:(uint32_t)preferredCodec
                  useFramePacing:(BOOL)useFramePacing
                       enableHdr:(BOOL)enableHdr
                  btMouseSupport:(BOOL)btMouseSupport
               absoluteTouchMode:(BOOL)absoluteTouchMode
                    statsOverlay:(BOOL)statsOverlay;

- (NSArray*) getHosts;
- (void) updateHost:(TemporaryHost*)host;
- (void) updateAppsForExistingHost:(TemporaryHost *)host;
- (void) removeHost:(TemporaryHost*)host;
- (void) removeApp:(TemporaryApp*)app;

- (TemporarySettings*) getSettings;

- (void) updateUniqueId:(NSString*)uniqueId;
- (NSString*) getUniqueId;

@end
