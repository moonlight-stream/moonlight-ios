//
//  ServerInfoResponse.m
//  Moonlight
//
//  Created by Diego Waxemberg on 2/1/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "ServerInfoResponse.h"
#import <libxml2/libxml/xmlreader.h>

@implementation ServerInfoResponse
@synthesize data, statusCode, statusMessage;

- (void) populateWithData:(NSData *)xml {
    self.data = xml;
    [super parseData];
}

- (void) populateHost:(TemporaryHost*)host {
    host.name = [[self getStringTag:TAG_HOSTNAME] trim];
    host.uuid = [[self getStringTag:TAG_UNIQUE_ID] trim];
    host.mac = [[self getStringTag:TAG_MAC_ADDRESS] trim];
    host.currentGame = [[self getStringTag:TAG_CURRENT_GAME] trim];
    
    NSInteger httpsPort;
    if ([self getIntTag:TAG_HTTPS_PORT value:&httpsPort]) {
        host.httpsPort = (unsigned short)httpsPort;
    }
    else {
        // Use the default if it's not specified
        host.httpsPort = 47984;
    }
    
    // We might get an IPv4 loopback address if we're using GS IPv6 Forwarder
    NSString *lanAddr = [[self getStringTag:TAG_LOCAL_IP] trim];
    if (![lanAddr hasPrefix:@"127."]) {
        unsigned short localPort;
        
        // If we reached this host through this port, store our port there
        if (host.activeAddress && [lanAddr isEqualToString:[Utils addressPortStringToAddress:host.activeAddress]]) {
            localPort = [Utils addressPortStringToPort:host.activeAddress];
        }
        else if (host.localAddress) {
            // If there's an existing local address, use the port from that
            localPort = [Utils addressPortStringToPort:host.localAddress];
        }
        else {
            // If all else fails, use 47989
            localPort = 47989;
        }
        
        host.localAddress = [Utils addressAndPortToAddressPortString:lanAddr port:localPort];
    }
    
    // This is a Sunshine extension for WAN port remapping
    NSInteger externalHttpPort;
    if (![self getIntTag:TAG_EXTERNAL_PORT value:&externalHttpPort]) {
        // Use our active port if it's not specified
        if (host.activeAddress) {
            externalHttpPort = [Utils addressPortStringToPort:host.activeAddress];
        }
        else {
            // Otherwise use the default
            externalHttpPort = 47989;
        }
    }
    
    // Modern GFE versions don't actually give us a WAN address anymore
    // so we leave the one that we populated from mDNS discovery via STUN.
    NSString *wanAddr = [[self getStringTag:TAG_EXTERNAL_IP] trim];
    if (wanAddr) {
        host.externalAddress = [Utils addressAndPortToAddressPortString:wanAddr port:externalHttpPort];
    }
    else if (host.externalAddress) {
        // If we have an external address (via STUN) already, we still need to populate the port
        host.externalAddress = [Utils addressAndPortToAddressPortString:[Utils addressPortStringToAddress:host.externalAddress] port:externalHttpPort];
    }
    
    NSString *state = [[self getStringTag:TAG_STATE] trim];
    if (![state hasSuffix:@"_SERVER_BUSY"]) {
        // GFE 2.8 started keeping currentgame set to the last game played. As a result, it no longer
        // has the semantics that its name would indicate. To contain the effects of this change as much
        // as possible, we'll force the current game to zero if the server isn't in a streaming session.
        host.currentGame = @"0";
    }
    
    // GFE uses the Mjolnir codename in their state enum values
    host.isNvidiaServerSoftware = [state containsString:@"MJOLNIR"];
    
    NSInteger pairStatus;
    if ([self getIntTag:TAG_PAIR_STATUS value:&pairStatus]) {
        host.pairState = pairStatus ? PairStatePaired : PairStateUnpaired;
    } else {
        host.pairState = PairStateUnknown;
    }
    
    NSString *serverCodecModeString = [self getStringTag:@"ServerCodecModeSupport"];
    if (serverCodecModeString != nil) {
        host.serverCodecModeSupport = [[serverCodecModeString trim] intValue];
    }
}

@end
