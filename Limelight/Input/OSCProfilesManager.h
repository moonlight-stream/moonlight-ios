//
//  OSCProfilesManager.h
//  Moonlight
//
//  Created by Long Le on 1/1/23.
//  Copyright © 2023 Moonlight Game Streaming Project. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OSCProfile.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSCProfilesManager : NSObject


+ (OSCProfilesManager *) sharedManager;

#pragma mark - Getters
/**
 * Returns OSC Profile that is currently selected to be displayed on screen during game streaming
 */
- (OSCProfile *) getSelectedProfile;


/**
 * Returns an array of decoded profile objects
 */
- (NSMutableArray *) getAllProfiles;


#pragma mark - Setters
/**
 * Sets the profile object that has a particular 'name' as the selected profile to be displayed on screen during game streaming
 */
- (void) setProfileToSelected:(NSString *)name;


/**
 * Saves a profile object that has a particular 'name' and an array of button layers (usually the button layers currently visible on screen during game streaming or the OSC layout customization view) to persistent storage
 */
- (void) saveProfileWithName:(NSString*)name andButtonLayers:(NSMutableArray *)buttonLayers;


#pragma mark - Queries
/**
 * Lets the caller of this method know whether a profile with a given name already exists in persistent storage
 */
- (BOOL) profileNameAlreadyExist:(NSString*)name;


@end

NS_ASSUME_NONNULL_END
