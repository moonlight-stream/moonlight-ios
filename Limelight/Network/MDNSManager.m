//
//  MDNSManager.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/14/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "MDNSManager.h"
#import "TemporaryHost.h"

#include <arpa/inet.h>

#include <Limelight.h>

@implementation MDNSManager {
    NSNetServiceBrowser* mDNSBrowser;
    NSMutableArray* services;
    BOOL scanActive;
    BOOL timerPending;
}

static NSString* NV_SERVICE_TYPE = @"_nvstream._tcp";

- (id) initWithCallback:(id<MDNSCallback>)callback {
    self = [super init];
    
    self.callback = callback;
    
    scanActive = FALSE;
    
    mDNSBrowser = [[NSNetServiceBrowser alloc] init];
    [mDNSBrowser setDelegate:self];
    
    services = [[NSMutableArray alloc] init];
    
    return self;
}

- (void) searchForHosts {
    if (scanActive) {
        return;
    }
    
    Log(LOG_I, @"Starting mDNS discovery");
    scanActive = TRUE;

    if (!timerPending) {
        timerPending = TRUE;

        // Just invoke the timer callback to save a little code
        [self startSearchTimerCallback:nil];
    }
}

- (void) stopSearching {
    if (!scanActive) {
        return;
    }
    
    Log(LOG_I, @"Stopping mDNS discovery");
    scanActive = FALSE;
    [mDNSBrowser stop];
}

- (void) forgetHosts {
    [services removeAllObjects];
}

+ (NSString*)sockAddrToString:(NSData*)addrData {
    char addrStr[INET6_ADDRSTRLEN];
    struct sockaddr* addr = (struct sockaddr*)[addrData bytes];
    if (addr->sa_family == AF_INET) {
        inet_ntop(addr->sa_family, &((struct sockaddr_in*)addr)->sin_addr, addrStr, sizeof(addrStr));
    }
    else {
        struct sockaddr_in6* sin6 = (struct sockaddr_in6*)addr;
        inet_ntop(addr->sa_family, &sin6->sin6_addr, addrStr, sizeof(addrStr));
        if (sin6->sin6_scope_id != 0) {
            // Link-local addresses with scope IDs are special
            return [NSString stringWithFormat: @"%s%%%u", addrStr, sin6->sin6_scope_id];
        }
    }
    return [NSString stringWithFormat: @"%s", addrStr];
}

+ (BOOL)isAddress:(uint8_t*)address inSubnet:(uint8_t*)subnet netmask:(int)bits {
    for (int i = 0; i < bits; i++) {
        uint8_t mask = 1 << (i % 8);
        if ((address[i / 8] & mask) != (subnet[i / 8] & mask)) {
            return NO;
        }
    }
    return YES;
}

+ (BOOL)isLocalIpv6Address:(NSData*)addrData {
    struct sockaddr_in6* sin6 = (struct sockaddr_in6*)[addrData bytes];
    if (sin6->sin6_family != AF_INET6) {
        return NO;
    }
    
    uint8_t* addrBytes = sin6->sin6_addr.s6_addr;
    uint8_t prefix[2];
    
    // fe80::/10
    prefix[0] = 0xfe;
    prefix[1] = 0x80;
    if ([MDNSManager isAddress:addrBytes inSubnet:prefix netmask:10]) {
        // Link-local
        return YES;
    }
    
    // fec0::/10
    prefix[0] = 0xfe;
    prefix[1] = 0xc0;
    if ([MDNSManager isAddress:addrBytes inSubnet:prefix netmask:10]) {
        // Site local
        return YES;
    }
    
    // fc00::/7
    prefix[0] = 0xfc;
    prefix[1] = 0x00;
    if ([MDNSManager isAddress:addrBytes inSubnet:prefix netmask:7]) {
        // ULA
        return YES;
    }
    
    return NO;
}

+ (NSString*)getBestIpv6Address:(NSArray<NSData*>*)addresses {
    for (NSData* addrData in addresses) {
        struct sockaddr_in6* sin6 = (struct sockaddr_in6*)[addrData bytes];
        if (sin6->sin6_family != AF_INET6) {
            continue;
        }
        
        if ([MDNSManager isLocalIpv6Address:addrData]) {
            // Skip non-global addresses
            continue;
        }
        
        uint8_t* addrBytes = sin6->sin6_addr.s6_addr;
        uint8_t prefix[2];
        
        // 2002::/16
        prefix[0] = 0x20;
        prefix[1] = 0x02;
        if ([MDNSManager isAddress:addrBytes inSubnet:prefix netmask:16]) {
            Log(LOG_I, @"Ignoring 6to4 address: %@", [MDNSManager sockAddrToString:addrData]);
            continue;
        }
        
        // 2001::/32
        prefix[0] = 0x20;
        prefix[1] = 0x01;
        if ([MDNSManager isAddress:addrBytes inSubnet:prefix netmask:32]) {
            Log(LOG_I, @"Ignoring Teredo address: %@", [MDNSManager sockAddrToString:addrData]);
            continue;
        }
        
        return [MDNSManager sockAddrToString:addrData];
    }
    
    return nil;
}

- (void)netServiceDidResolveAddress:(NSNetService *)service {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray<NSData*>* addresses = [service addresses];
        
        for (NSData* addrData in addresses) {
            Log(LOG_I, @"Resolved address: %@ -> %@", [service hostName], [MDNSManager sockAddrToString: addrData]);
        }
        
        TemporaryHost* host = [[TemporaryHost alloc] init];
        
        // First, look for an IPv4 record for the local address
        for (NSData* addrData in addresses) {
            struct sockaddr_in* sin = (struct sockaddr_in*)[addrData bytes];
            if (sin->sin_family != AF_INET) {
                continue;
            }
            
            // Don't send a STUN request if we're connected to a VPN. We'll likely get the VPN
            // gateway's external address rather than the external address of the LAN.
            if (![Utils isActiveNetworkVPN]) {
                // Since we discovered this host over IPv4 mDNS, we know we're on the same network
                // as the PC and we can use our current WAN address as a likely candidate
                // for our PC's external address.
                struct in_addr wanAddr;
                int err = LiFindExternalAddressIP4("stun.moonlight-stream.org", 3478, &wanAddr.s_addr);
                if (err == 0) {
                    char addrStr[INET_ADDRSTRLEN];
                    inet_ntop(AF_INET, &wanAddr, addrStr, sizeof(addrStr));
                    host.externalAddress = [NSString stringWithFormat: @"%s", addrStr];
                    Log(LOG_I, @"External IPv4 address (STUN): %@ -> %@", [service hostName], host.externalAddress);
                }
                else {
                    Log(LOG_E, @"STUN failed to get WAN address: %d", err);
                }
            }
            
            host.localAddress = [MDNSManager sockAddrToString:addrData];
            Log(LOG_I, @"Local address chosen: %@ -> %@", [service hostName], host.localAddress);
            break;
        }
        
        if (host.localAddress == nil) {
            // If we didn't find an IPv4 record, look for a local IPv6 record
            for (NSData* addrData in addresses) {
                if ([MDNSManager isLocalIpv6Address:addrData]) {
                    host.localAddress = [MDNSManager sockAddrToString:addrData];
                    Log(LOG_I, @"Local address chosen: %@ -> %@", [service hostName], host.localAddress);
                    break;
                }
            }
        }
        
        host.ipv6Address = [MDNSManager getBestIpv6Address:addresses];
        Log(LOG_I, @"IPv6 address chosen: %@ -> %@", [service hostName], host.ipv6Address);
        
        host.activeAddress = host.localAddress;
        host.name = service.hostName;
        [self.callback updateHost:host];
    });
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary *)errorDict {
    Log(LOG_W, @"Did not resolve address for: %@\n%@", sender, [errorDict description]);
    
    // Schedule a retry in 2 seconds
    [NSTimer scheduledTimerWithTimeInterval:2.0
                                     target:self
                                   selector:@selector(retryResolveTimerCallback:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    Log(LOG_D, @"Found service: %@", aNetService);
    
    if (![services containsObject:aNetService]) {
        Log(LOG_I, @"Found new host: %@", aNetService.name);
        [aNetService setDelegate:self];
        [aNetService resolveWithTimeout:5];
        [services addObject:aNetService];
    }
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing {
    Log(LOG_I, @"Removing service: %@", aNetService);
    [services removeObject:aNetService];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didNotSearch:(NSDictionary *)errorDict {
    Log(LOG_W, @"Did not perform search: \n%@", [errorDict description]);
    
    // We'll schedule a retry in startSearchTimerCallback
}

- (void)startSearchTimerCallback:(NSTimer *)timer {
    // Check if we've been stopped since this was queued
    if (!scanActive) {
        timerPending = FALSE;
        return;
    }
    
    Log(LOG_D, @"Restarting mDNS search");
    [mDNSBrowser stop];
    [mDNSBrowser searchForServicesOfType:NV_SERVICE_TYPE inDomain:@""];
    
    // Search again in 5 seconds. We need to do this because
    // we want more aggressive querying than Bonjour will normally
    // do for when we're at the hosts screen. This also covers scenarios
    // where discovery didn't work, like if WiFi was disabled.
    [NSTimer scheduledTimerWithTimeInterval:5.0
                                     target:self
                                   selector:@selector(startSearchTimerCallback:)
                                   userInfo:nil
                                    repeats:NO];
}

- (void)retryResolveTimerCallback:(NSTimer *)timer {
    // Check if we've been stopped since this was queued
    if (!scanActive) {
        return;
    }
    
    Log(LOG_I, @"Retrying mDNS resolution");
    for (NSNetService* service in services) {
        if (service.hostName == nil) {
            [service setDelegate:self];
            [service resolveWithTimeout:5];
        }
    }
}

@end
