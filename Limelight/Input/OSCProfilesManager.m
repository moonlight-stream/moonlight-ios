//
//  OSCProfilesManager.m
//  Moonlight
//
//  Created by Long Le on 1/1/23.
//  Copyright © 2023 Moonlight Game Streaming Project. All rights reserved.
//

#import "OSCProfilesManager.h"

@implementation OSCProfilesManager

#pragma mark - Initializer

+ (OSCProfilesManager *) sharedManager {
    static OSCProfilesManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
}


#pragma mark - Class Helper Methods

- (OSCProfile *) OSCProfileWithName:(NSString*)name {
    // Get the encoded array of encoded OSC profiles from persistent storage
    NSData *profilesArrayEncoded = [[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    
    // Decode the encoded array itself, NOT the objects contained in the array
    NSMutableArray *encodedProfiles = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profilesArrayEncoded error:nil];
    
    
    /* Decode each OSC profile in the array. Iterate through the array and return the first OSC profile whose 'name' property equals the 'name' parameter passed into this method */
    OSCProfile *profileDecoded;
    for (NSData *profile in encodedProfiles) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profile error:nil];
        
        if ([profileDecoded.name isEqualToString:name]) {
            return profileDecoded;
        }
    }
    
    return nil;
}

- (void) replaceProfile:(OSCProfile*)oldProfile withProfile:(OSCProfile*)newProfile {
    // Get the encoded array of encoded OSC profiles from persistent storage
    NSData *profilesArrayEncoded = [[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    
    // Decode the encoded array itself, NOT the objects contained in the array
    NSMutableArray *encodedProfiles = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profilesArrayEncoded error: nil];

    /* Set the new profile as the selected one. The reasoning for this is that this method is currently being used when the user saves over an existing profile with another one of the same name. The expected behavior is that the newly saved profile becomes the selected profile which will show on screen when they launch the game stream view */
    newProfile.isSelected = YES;
    
    /* Iterate through the array of encoded profiles, decode each profile, and place them in a new array */
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in encodedProfiles) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
        
    /* Remove the old profile from the array and insert the new profile into its place */
    int index = 0;
    for (int i = 0; i < profilesDecoded.count; i++) {
        
        if ([[profilesDecoded[i] name] isEqualToString: oldProfile.name]) {
            
            index = i;
        }
    }
    [profilesDecoded removeObjectAtIndex:index];
    [profilesDecoded insertObject:newProfile atIndex:index];
    
    /* Encode each of the profiles and place them into an array */
    [encodedProfiles removeAllObjects];
    for (OSCProfile *profileDecoded in profilesDecoded) {
        
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
        [encodedProfiles addObject:profileEncoded];
    }
    
    /* Encode the array itself, which contains encoded profiles. Save it to persistent storage */
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:encodedProfiles requiringSecureCoding:YES error:nil];
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


#pragma mark - Globally Accessible Methods

- (OSCProfile *)getSelectedProfile {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profileEncoded error:nil];
        
        if (profileDecoded.isSelected) {
            
            return profileDecoded;
        }
    }
    
    return nil;
}

- (void) setProfileToSelected:(NSString *)name {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    for (NSData *profileEncoded in profilesEncoded) {
        
        OSCProfile *profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
    
    for (OSCProfile *profile in profilesDecoded) {
                
        if ([profile.name isEqualToString:name]) {
            
            profile.isSelected = YES;
        }
        else {
            
            profile.isSelected = NO;
        }
    }
    
    [profilesEncoded removeAllObjects];
    for (OSCProfile *profileDecoded in profilesDecoded) {   //add encoded profiles back into an array
        
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
        [profilesEncoded addObject:profileEncoded];
    }
        
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
    
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (BOOL) profileNameAlreadyExist:(NSString*)name {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
    
    for (OSCProfile *profile in profilesDecoded) {
        
        if ([profile.name isEqualToString:name]) {
            
            return YES;
        }
    }
    
    return NO;
}

- (void)saveProfileWithName:(NSString*)name andButtonLayers:(NSMutableArray *)buttonLayers {

    //Get button positions currently on screen and save them to array
    NSMutableArray *OSCButtonStates = [[NSMutableArray alloc] init];    //array will contain 'OnScreenButtonState' objects for OSC button on screen. Each 'buttonState' contains the name, position, hidden state of that button
    
    for (CALayer *buttonLayer in buttonLayers) {    //iterate through each OSC button the user sees on screen, create an 'OnScreenButtonState' object from each button, and then add the object to an array that will be saved to storage later

        OnScreenButtonState *onScreenButtonState = [[OnScreenButtonState alloc] initWithButtonName:buttonLayer.name  isHidden:buttonLayer.isHidden andPosition:buttonLayer.position];
        [OSCButtonStates addObject:onScreenButtonState];
    }

    NSMutableArray *saveableOSCButtonStates = [[NSMutableArray alloc] init];    //will contain an array of 'OnScreenButtonState' objects converted to a saveable data format

    for (OnScreenButtonState *buttonState in OSCButtonStates) { //convert each 'OnScreenButtonState' object in the array into a saveable data object

        NSData *buttonStateDataObject = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [saveableOSCButtonStates addObject: buttonStateDataObject];
    }

    //create a new OSCProfile with the buttonStates array created above
    OSCProfile *newProfile = [[OSCProfile alloc] initWithName:name buttonStates:saveableOSCButtonStates isSelected:YES];

    //Get an array of all currently saved OSCProfiles from persistent storage
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
    
    NSMutableArray *encodedProfilesEncoded = [[NSMutableArray alloc] init];
    for (OSCProfile *profile in profilesDecoded) {   //set all saved OSCProfiles 'isSelected' bool to NO since the one you're saving will be set as the selected profile
        
        profile.isSelected = NO;
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profile requiringSecureCoding:YES error:nil];
        [encodedProfilesEncoded addObject:profileEncoded];
    }
    
    if ([self profileNameAlreadyExist:name]) {  //if profile with 'name' already exists then overwrite it
        
                        
        [self replaceProfile:[self OSCProfileWithName:name] withProfile:newProfile];
    }
    else {  //otherwise encode then add the new profile to the end of the OSCProfiles array
        
        NSData *newProfileEncoded= [NSKeyedArchiver archivedDataWithRootObject:newProfile requiringSecureCoding:YES error:nil];
        [encodedProfilesEncoded addObject:newProfileEncoded];
        
        //try encoding profilesEncoded and saving it to user defaults then try decoding it below this method
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:encodedProfilesEncoded requiringSecureCoding:YES error:nil];
        
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (NSMutableArray *)getProfiles {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSError *error;
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: &error];
    
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
    
    return profilesDecoded;
}





@end
