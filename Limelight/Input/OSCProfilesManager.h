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

/**
 * Returns OSC Profile that is currently selected to be displayed on screen during game streaming
 */
- (OSCProfile *) selectedProfile;

/**
 * Returns an array of decoded profile objects in an
 */
- (NSMutableArray *) profilesDecoded;

/**
 * Sets the profile object with 'name' as the selected profile to be displayed on screen during game streaming
 */
- (void) setProfileToSelected:(NSString *)name;

/**
 * Saves a profile object with a 'name' and an array of buttonLayers to persistent storage
 */
- (void) saveProfileWithName:(NSString*)name andButtonLayers:(NSMutableArray *)buttonLayers;

/**
 * Lets caller know whether a profile with a given name already exists
 */
- (BOOL) profileNameAlreadyExist:(NSString*)name;


@end

NS_ASSUME_NONNULL_END
