//
//  WakeOnLanManager.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/2/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "TemporaryHost.h"

typedef enum {
    WAKE_ERROR   = -1,
    WAKE_SENT    = 0,
    WAKE_SKIPPED = 1
} WakeStatus;

typedef WakeStatus (^WakeBlock)(struct ifaddrs *ifa);

@interface WakeOnLanManager : NSObject

+ (void) getIPv4NetworkInterfacesWithVisitor:(WakeBlock)visitor;
+ (void) wakeHost:(TemporaryHost*)host;

@end
