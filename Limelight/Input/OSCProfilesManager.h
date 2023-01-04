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


+ (OSCProfilesManager *)sharedManager;
- (OSCProfile *)selectedProfile;
- (void)setProfileWithNameAsSelected: (NSString *)name;
- (BOOL)profileNameAlreadyExist: (NSString*)name;
- (void)saveProfileWithName: (NSString*)name andButtonLayers: (NSMutableArray *)buttonLayers;
- (NSMutableArray *)profilesDecoded;


@end

NS_ASSUME_NONNULL_END
