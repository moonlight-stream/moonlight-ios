//
//  DataManager.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/28/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "DataManager.h"
#import "TemporaryApp.h"
#import "TemporarySettings.h"

@implementation DataManager {
    NSManagedObjectContext *_managedObjectContext;
    AppDelegate *_appDelegate;
}

- (id) init {
    self = [super init];
    
    // HACK: Avoid calling [UIApplication delegate] off the UI thread to keep
    // Main Thread Checker happy.
    if ([NSThread isMainThread]) {
        _appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
    }
    else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            self->_appDelegate = (AppDelegate *)[[UIApplication sharedApplication] delegate];
        });
    }
    
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_managedObjectContext setParentContext:[_appDelegate managedObjectContext]];
    
    return self;
}

- (void) updateUniqueId:(NSString*)uniqueId {
    [_managedObjectContext performBlockAndWait:^{
        [self retrieveSettings].uniqueId = uniqueId;
        [self saveData];
    }];
}

- (NSString*) getUniqueId {
    __block NSString *uid;
    
    [_managedObjectContext performBlockAndWait:^{
        uid = [self retrieveSettings].uniqueId;
    }];

    return uid;
}

- (void) saveSettingsWithBitrate:(NSInteger)bitrate
                       framerate:(NSInteger)framerate
                          height:(NSInteger)height
                           width:(NSInteger)width
                     audioConfig:(NSInteger)audioConfig
                onscreenControls:(NSInteger)onscreenControls
                   optimizeGames:(BOOL)optimizeGames
                 multiController:(BOOL)multiController
                 swapABXYButtons:(BOOL)swapABXYButtons
                       audioOnPC:(BOOL)audioOnPC
                  preferredCodec:(uint32_t)preferredCodec
                  useFramePacing:(BOOL)useFramePacing
                       enableHdr:(BOOL)enableHdr
                  btMouseSupport:(BOOL)btMouseSupport
               absoluteTouchMode:(BOOL)absoluteTouchMode
                    statsOverlay:(BOOL)statsOverlay {
    
    [_managedObjectContext performBlockAndWait:^{
        Settings* settingsToSave = [self retrieveSettings];
        settingsToSave.framerate = [NSNumber numberWithInteger:framerate];
        settingsToSave.bitrate = [NSNumber numberWithInteger:bitrate];
        settingsToSave.height = [NSNumber numberWithInteger:height];
        settingsToSave.width = [NSNumber numberWithInteger:width];
        settingsToSave.audioConfig = [NSNumber numberWithInteger:audioConfig];
        settingsToSave.onscreenControls = [NSNumber numberWithInteger:onscreenControls];
        settingsToSave.optimizeGames = optimizeGames;
        settingsToSave.multiController = multiController;
        settingsToSave.swapABXYButtons = swapABXYButtons;
        settingsToSave.playAudioOnPC = audioOnPC;
        settingsToSave.preferredCodec = preferredCodec;
        settingsToSave.useFramePacing = useFramePacing;
        settingsToSave.enableHdr = enableHdr;
        settingsToSave.btMouseSupport = btMouseSupport;
        settingsToSave.absoluteTouchMode = absoluteTouchMode;
        settingsToSave.statsOverlay = statsOverlay;
        
        [self saveData];
    }];
}

- (void) updateHost:(TemporaryHost *)host {
    [_managedObjectContext performBlockAndWait:^{
        // Add a new persistent managed object if one doesn't exist
        Host* parent = [self getHostForTemporaryHost:host withHostRecords:[self fetchRecords:@"Host"]];
        if (parent == nil) {
            NSEntityDescription* entity = [NSEntityDescription entityForName:@"Host" inManagedObjectContext:self->_managedObjectContext];
            parent = [[Host alloc] initWithEntity:entity insertIntoManagedObjectContext:self->_managedObjectContext];
        }
        
        // Push changes from the temp host to the persistent one
        [host propagateChangesToParent:parent];
        
        [self saveData];
    }];
}

#if TARGET_OS_TV

- (NSDictionary *)dictionaryFromApp:(App *)app {
    return @{@"hostUUID": app.host.uuid, @"hostName": app.host.name, @"name": app.name, @"id": app.id };
}

- (void)moveAppUpInList:(NSString *)appId {
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.MoonlightTV"];
    NSString *json = [sharedDefaults objectForKey:@"appList"];
    NSData *jsonData = [json dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *apps = [NSJSONSerialization JSONObjectWithData:jsonData options:NSJSONReadingMutableContainers error:nil];
    
    // Identify the selected app and its index
    NSDictionary *selectedApp = nil;
    NSInteger selectedIndex = NSNotFound;
    for (NSDictionary *app in apps) {
        if ([app[@"id"] isEqualToString:appId]) {
            selectedApp = app;
            selectedIndex = [apps indexOfObject:app];
            break;
        }
    }

    if (selectedApp && selectedIndex != NSNotFound) {
        // Move the app to the top of the list
        [apps removeObjectAtIndex:selectedIndex];
        [apps insertObject:selectedApp atIndex:0];

        // Serialize to JSON and save back to user defaults
        NSData *newJsonData = [NSJSONSerialization dataWithJSONObject:apps options:0 error:nil];
        NSString *newJsonStr = [[NSString alloc] initWithData:newJsonData encoding:NSUTF8StringEncoding];
        [sharedDefaults setObject:newJsonStr forKey:@"appList"];
        
        // Update hostUUIDOrder accordingly
        NSString *hostUUID = selectedApp[@"hostUUID"];
        NSMutableArray *hostUUIDOrder = [[sharedDefaults objectForKey:@"hostUUIDOrder"] mutableCopy];
        if (!hostUUIDOrder) {
            hostUUIDOrder = [NSMutableArray array];
        }
        [hostUUIDOrder removeObject:hostUUID];
        [hostUUIDOrder insertObject:hostUUID atIndex:0];
        [sharedDefaults setObject:hostUUIDOrder forKey:@"hostUUIDOrder"];
        
        // Synchronize changes
        [sharedDefaults synchronize];
        
    } else {
        NSLog(@"App with ID %@ not found.", appId);
    }
}
#endif

- (void) updateAppsForExistingHost:(TemporaryHost *)host {
    [_managedObjectContext performBlockAndWait:^{
        Host* parent = [self getHostForTemporaryHost:host withHostRecords:[self fetchRecords:@"Host"]];
        if (parent == nil) {
            // The host must exist to be updated
            return;
        }
        
        NSMutableSet *applist = [[NSMutableSet alloc] init];
        NSArray *appRecords = [self fetchRecords:@"App"];
        for (TemporaryApp* app in host.appList) {
            // Add a new persistent managed object if one doesn't exist
            App* parentApp = [self getAppForTemporaryApp:app withAppRecords:appRecords];
            if (parentApp == nil) {
                NSEntityDescription* entity = [NSEntityDescription entityForName:@"App" inManagedObjectContext:self->_managedObjectContext];
                parentApp = [[App alloc] initWithEntity:entity insertIntoManagedObjectContext:self->_managedObjectContext];
            }
            
            [app propagateChangesToParent:parentApp withHost:parent];
            
            [applist addObject:parentApp];
        }
        
        parent.appList = applist;
        
        [self saveData];
    }];
}

- (TemporarySettings*) getSettings {
    __block TemporarySettings *tempSettings;
    
    [_managedObjectContext performBlockAndWait:^{
        tempSettings = [[TemporarySettings alloc] initFromSettings:[self retrieveSettings]];
    }];
    
    return tempSettings;
}

- (Settings*) retrieveSettings {
    NSArray* fetchedRecords = [self fetchRecords:@"Settings"];
    if (fetchedRecords.count == 0) {
        // create a new settings object with the default values
        NSEntityDescription* entity = [NSEntityDescription entityForName:@"Settings" inManagedObjectContext:_managedObjectContext];
        Settings* settings = [[Settings alloc] initWithEntity:entity insertIntoManagedObjectContext:_managedObjectContext];
        
        return settings;
    } else {
        // we should only ever have 1 settings object stored
        return [fetchedRecords objectAtIndex:0];
    }
}

- (void) removeApp:(TemporaryApp*)app {
    [_managedObjectContext performBlockAndWait:^{
        App* managedApp = [self getAppForTemporaryApp:app withAppRecords:[self fetchRecords:@"App"]];
        if (managedApp != nil) {
            [self->_managedObjectContext deleteObject:managedApp];
            [self saveData];
        }
    }];
}

- (void) removeHost:(TemporaryHost*)host {
    [_managedObjectContext performBlockAndWait:^{
        Host* managedHost = [self getHostForTemporaryHost:host withHostRecords:[self fetchRecords:@"Host"]];
        if (managedHost != nil) {
            [self->_managedObjectContext deleteObject:managedHost];
            [self saveData];
            
            
        }
    }];
}

- (void) saveData {
    NSError* error;
    if ([_managedObjectContext hasChanges] && ![_managedObjectContext save:&error]) {
        Log(LOG_E, @"Unable to save hosts to database: %@", error);
    }
    [_appDelegate saveContext];
    

#if TARGET_OS_TV
    // Save hosts/apps for Top Shelf
    NSArray *hosts = [self fetchRecords:@"Host"];
    NSUserDefaults *sharedDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.MoonlightTV"];
    NSString *existingJson = [sharedDefaults objectForKey:@"appList"];
    
    // Retrieve the existing order of host UUIDs
    NSMutableArray *storedUUIDOrder = [[sharedDefaults objectForKey:@"hostUUIDOrder"] mutableCopy];
    if (!storedUUIDOrder) {
        storedUUIDOrder = [NSMutableArray array];
    }
    // Update storedUUIDOrder if new hosts are added
    for (Host* host in hosts) {
        if (![storedUUIDOrder containsObject:host.uuid]) {
            [storedUUIDOrder addObject:host.uuid];
        }
    }
    // Save the updated order back to User Defaults
    [sharedDefaults setObject:storedUUIDOrder forKey:@"hostUUIDOrder"];
    [sharedDefaults synchronize];
    
    // Sort hosts by order
    hosts = [hosts sortedArrayUsingComparator:^NSComparisonResult(Host* a, Host* b) {
        NSUInteger first = [storedUUIDOrder indexOfObject:a.uuid];
        NSUInteger second = [storedUUIDOrder indexOfObject:b.uuid];
        if (first < second) {
            return NSOrderedAscending;
        } else if (first > second) {
            return NSOrderedDescending;
        } else {
            return NSOrderedSame;
        }
    }];
    
    NSArray *existingApps;
    if (existingJson != nil) {
        existingApps = [NSJSONSerialization JSONObjectWithData:[existingJson dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
    } else {
        existingApps = [NSArray array];
    }

    NSMutableArray *mutableExistingApps = [existingApps mutableCopy];
    NSMutableSet *currentHostUUIDs = [NSMutableSet set];

    for (Host* host in hosts) {
        
        [currentHostUUIDs addObject:host.uuid];
        
        if ([host.appList count]>0) {
            NSMutableDictionary *hostAppMap = [NSMutableDictionary dictionary];
            for (NSDictionary *app in existingApps) {
                hostAppMap[app[@"hostUUID"]] = app;
            }
            
            NSMutableSet *currentAppIds = [NSMutableSet set];
            
            for (App *app in host.appList) {
                [currentAppIds addObject:app.id];
                NSDictionary *newAppDict = [self dictionaryFromApp:app];
                NSUInteger existingIndex = [mutableExistingApps indexOfObjectPassingTest:^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                    return [dict[@"id"] isEqualToString:app.id];
                }];
                
                if (existingIndex != NSNotFound) {
                    mutableExistingApps[existingIndex] = newAppDict;
                } else {
                    [mutableExistingApps addObject:newAppDict];
                }
            }
                        
            // Removing apps not in source list for this host
            NSIndexSet *indexesToDelete = [mutableExistingApps indexesOfObjectsPassingTest:^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
                return ![currentAppIds containsObject:dict[@"id"]] && [dict[@"hostUUID"] isEqualToString:host.uuid];
            }];
            [mutableExistingApps removeObjectsAtIndexes:indexesToDelete];
        }
    }
    
    // Remove apps belonging to hosts that are no longer there
    NSIndexSet *indexesToDelete = [mutableExistingApps indexesOfObjectsPassingTest:^BOOL(NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        return ![currentHostUUIDs containsObject:dict[@"hostUUID"]];
    }];
    [mutableExistingApps removeObjectsAtIndexes:indexesToDelete];
    
    // Partition into separate arrays
    NSMutableDictionary<NSString *, NSMutableArray *> *hostToAppsMap = [NSMutableDictionary new];
    for (NSDictionary *app in mutableExistingApps) {
        NSString *hostUUID = app[@"hostUUID"];
        if (!hostToAppsMap[hostUUID]) {
            hostToAppsMap[hostUUID] = [NSMutableArray new];
        }
        [hostToAppsMap[hostUUID] addObject:app];
    }

    // Sort these arrays
    NSArray *sortedKeys = [hostToAppsMap.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
        NSUInteger first = [storedUUIDOrder indexOfObject:a];
        NSUInteger second = [storedUUIDOrder indexOfObject:b];
        return first < second ? NSOrderedAscending : NSOrderedDescending;
    }];

    // Merge them back
    [mutableExistingApps removeAllObjects];
    for (NSString *key in sortedKeys) {
        [mutableExistingApps addObjectsFromArray:hostToAppsMap[key]];
    }
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:mutableExistingApps options:0 error:&error];
    if (jsonData) {
        NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        [sharedDefaults setObject:jsonStr forKey:@"appList"];
        [sharedDefaults synchronize];
    }

#endif
}

- (NSArray*) getHosts {
    __block NSMutableArray *tempHosts = [[NSMutableArray alloc] init];
    
    [_managedObjectContext performBlockAndWait:^{
        NSArray *hosts = [self fetchRecords:@"Host"];
        
        for (Host* host in hosts) {
            [tempHosts addObject:[[TemporaryHost alloc] initFromHost:host]];
        }
    }];
    
    return tempHosts;
}

// Only call from within performBlockAndWait!!!
- (Host*) getHostForTemporaryHost:(TemporaryHost*)tempHost withHostRecords:(NSArray*)hosts {
    for (Host* host in hosts) {
        if ([tempHost.uuid isEqualToString:host.uuid]) {
            return host;
        }
    }
    
    return nil;
}

// Only call from within performBlockAndWait!!!
- (App*) getAppForTemporaryApp:(TemporaryApp*)tempApp withAppRecords:(NSArray*)apps {
    for (App* app in apps) {
        if ([app.id isEqualToString:tempApp.id] &&
            [app.host.uuid isEqualToString:tempApp.host.uuid]) {
            return app;
        }
    }
    
    return nil;
}

- (NSArray*) fetchRecords:(NSString*)entityName {
    NSArray* fetchedRecords;
    
    NSFetchRequest* fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription* entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:_managedObjectContext];
    [fetchRequest setEntity:entity];
    
    NSError* error;
    fetchedRecords = [_managedObjectContext executeFetchRequest:fetchRequest error:&error];
    //TODO: handle errors
    
    return fetchedRecords;
}

@end

