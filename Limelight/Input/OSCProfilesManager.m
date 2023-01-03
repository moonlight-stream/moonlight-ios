//
//  OSCProfilesManager.m
//  Moonlight
//
//  Created by Long Le on 1/1/23.
//  Copyright © 2023 Moonlight Game Streaming Project. All rights reserved.
//

#import "OSCProfilesManager.h"

@implementation OSCProfilesManager

@synthesize OSCButtonLayers;

+ (OSCProfilesManager *)sharedManager {
    static OSCProfilesManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc] init];
    });
    return _sharedManager;
}

- (id)init {
    self = [super init];
    if (self) {
        OSCButtonLayers = [[NSMutableArray alloc] init];
    }
    return self;
}

- (OSCProfile *)selectedOSCProfile {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        NSError *error;
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profileEncoded error:nil];
        
        if (profileDecoded.isSelected) {
            
            return profileDecoded;
        }
    }
    
    return nil;
}

- (void) setOSCProfileAsSelectedWithName: (NSString *)name {
    
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

//Returns the OSCProfile with the given name
- (NSData *)OSCProfileWithName: (NSString*)name {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    OSCProfile *profileDecoded;
    for (NSData *profile in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profile error:nil];
        
        if ([profileDecoded.name isEqualToString:name]) {
            
            NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
            
            return profileEncoded;
        }
    }
    
    return nil;
}

- (BOOL)profileNameAlreadyExist: (NSString*)name {
    
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

- (void)saveOSCProfileWithName: (NSString*)name {

    //Get button positions currently on screen and save them to array
    NSMutableArray *OSCButtonStates = [[NSMutableArray alloc] init];    //array will contain 'OnScreenButtonState' objects for OSC button on screen. Each 'buttonState' contains the name, position, hidden state of that button
    
    for (CALayer *buttonLayer in OSCButtonLayers) {    //iterate through each OSC button the user sees on screen, create an 'OnScreenButtonState' object from each button, and then add the object to an array that will be saved to storage later

        OnScreenButtonState *onScreenButtonState = [[OnScreenButtonState alloc] initWithButtonName:buttonLayer.name  isHidden:buttonLayer.isHidden andPosition:buttonLayer.position];
        [OSCButtonStates addObject:onScreenButtonState];
    }

    NSMutableArray *saveableOSCButtonStates = [[NSMutableArray alloc] init];    //will contain an array of 'OnScreenButtonState' objects converted to a saveable data format

    for (OnScreenButtonState *buttonState in OSCButtonStates) { //convert each 'OnScreenButtonState' object in the array into a saveable data object

        NSData *buttonStateDataObject = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [saveableOSCButtonStates addObject: buttonStateDataObject];
    }
    
    
    
    //create a new OSCProfile with the buttonStates array created above
    OSCProfile *newProfileDecoded = [[OSCProfile alloc] initWithName:name buttonStates:saveableOSCButtonStates isSelected:YES];
    NSData *newProfileEncoded = [NSKeyedArchiver archivedDataWithRootObject:newProfileDecoded requiringSecureCoding:YES error:nil];

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
        
        NSData *oldProfileEncoded = [self OSCProfileWithName:name];
                        
        [self replaceOSCProfile:oldProfileEncoded withOSCProfile:newProfileEncoded];
    }
    else {  //otherwise add the new profile to the end of the OSCProfiles array
                
        [encodedProfilesEncoded addObject:newProfileEncoded];
        
        //try encoding profilesEncoded and saving it to user defaults then try decoding it below this method
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:encodedProfilesEncoded requiringSecureCoding:YES error:nil];
        
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
}

- (void)replaceOSCProfile: (NSData*)oldProfile withOSCProfile: (NSData*)newProfile {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    NSError *error;
    OSCProfile *newProfileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:newProfile error: &error];
    newProfileDecoded.isSelected = YES;
    
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
    
    OSCProfile *oldProfileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:oldProfile error: nil];
    
    int index = 0;
    for (int i = 0; i < profilesDecoded.count; i++) {
        
        if ([[profilesDecoded[i] name] isEqualToString: oldProfileDecoded.name]) {
            
            index = i;
        }
    }
    
    [profilesDecoded removeObjectAtIndex:index];
    [profilesDecoded insertObject:newProfileDecoded atIndex:index];
    
    [profilesEncoded removeAllObjects];
    for (OSCProfile *profileDecoded in profilesDecoded) {   //add encoded profiles back into an array
        
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
        [profilesEncoded addObject:profileEncoded];
    }
    
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:&error];
    
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}


@end
