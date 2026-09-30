//
//  WakeOnLanManager.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/2/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "WakeOnLanManager.h"
#import "Utils.h"
#import <CoreFoundation/CoreFoundation.h>
#import <net/if.h>
#import <ifaddrs.h>
#import <sys/socket.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <netdb.h>

@implementation WakeOnLanManager

static const int WOL_PORT = 9;

+ (void) getIPv4NetworkInterfacesWithVisitor:(WakeBlock)visitor {
    struct ifaddrs *ifaddr, *ifa;

    if (getifaddrs(&ifaddr) == -1) {
        Log(LOG_E, @"WakeOnLanManager: Unable to get the list of network interfaces");
        return;
    }

    for (ifa = ifaddr; ifa != NULL; ifa = ifa->ifa_next) {
        if (ifa->ifa_addr->sa_family == AF_INET) {
            visitor(ifa);
            logInterfaceDetails(ifa);
        }
    }

    freeifaddrs(ifaddr);
}

static void logInterfaceDetails(struct ifaddrs *ifa) {
    int family;
    char addr_str[INET_ADDRSTRLEN];
    char netmask_str[INET_ADDRSTRLEN];
    char broadcast_str[INET_ADDRSTRLEN];

    family = ifa->ifa_addr->sa_family;

    if (family == AF_INET) {
        struct sockaddr_in *addr = (struct sockaddr_in *)ifa->ifa_addr;
        inet_ntop(AF_INET, &addr->sin_addr, addr_str, sizeof(addr_str));

        if (ifa->ifa_netmask) {
            struct sockaddr_in *netmask = (struct sockaddr_in *)ifa->ifa_netmask;
            inet_ntop(AF_INET, &netmask->sin_addr, netmask_str, sizeof(netmask_str));
        }

        if (ifa->ifa_broadaddr) {
            struct sockaddr_in *broadcast = (struct sockaddr_in *)ifa->ifa_broadaddr;
            inet_ntop(AF_INET, &broadcast->sin_addr, broadcast_str, sizeof(broadcast_str));
        }

        Log(LOG_D, @"WakeOnLanManager: Interface %s ip4:%s mask:%s bcast:%s", ifa->ifa_name, addr_str, netmask_str, broadcast_str);
    }
}

+ (void) wakeHost:(TemporaryHost*)host {
    NSData* wolPayload = [WakeOnLanManager createPayload:host];

    [WakeOnLanManager getIPv4NetworkInterfacesWithVisitor:(WakeBlock)^(struct ifaddrs *ifa) {
        if (ifa->ifa_addr->sa_family != AF_INET) return WAKE_SKIPPED; // we can only wake over IPv4
        if (!(ifa->ifa_flags & IFF_UP))          return WAKE_SKIPPED; // interface is not up
        if (!(ifa->ifa_flags & IFF_BROADCAST))   return WAKE_SKIPPED; // broadcast address is not valid

        int success;
        ssize_t bytesSent = 0;
        struct sockaddr_in destAddr;
        char broadcast_str[INET_ADDRSTRLEN];

        int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
        static const int kOne = 1;
        success = setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &kOne, sizeof(kOne)) == 0;
        if (success < 0) {
            Log(LOG_W, @"Wake-on-LAN packet for %@ failed to set SO_BROADCAST, error: %s", host.mac, strerror(errno));
            return WAKE_ERROR;
        }

        int ifIndex = if_nametoindex(ifa->ifa_name);
        success = setsockopt(fd, IPPROTO_IP, IP_BOUND_IF, &ifIndex, sizeof(ifIndex)) == 0;
        if (success < 0) {
            Log(LOG_W, @"Wake-on-LAN packet for %@ failed to IP_BOUND_IF, error: %s", host.mac, strerror(errno));
            return WAKE_ERROR;
        }

        struct sockaddr_in *broadcast = (struct sockaddr_in *)ifa->ifa_broadaddr;
        inet_ntop(AF_INET, &broadcast->sin_addr, broadcast_str, sizeof(broadcast_str));

        // send the packet to the subnet's broadcast address on UDP port 9
        memset(&destAddr, 0, sizeof(destAddr));
        destAddr.sin_family = AF_INET;
        destAddr.sin_len = sizeof(destAddr);
        inet_pton(AF_INET, broadcast_str, &destAddr.sin_addr.s_addr);
        destAddr.sin_port = htons(WOL_PORT);

        bytesSent = sendto(fd, [wolPayload bytes], [wolPayload length], 0, (const struct sockaddr *)&destAddr, sizeof(destAddr));
        if (bytesSent >= 0) {
            Log(LOG_I, @"Wake-on-LAN packet for %@ sent out interface %s to broadcast %s", host.mac, ifa->ifa_name, broadcast_str);
        }
        else {
            Log(LOG_W, @"Wake-on-LAN packet for %@ failed to send, error: %d", host.mac, strerror(errno));
            return WAKE_ERROR;
        }
        close(fd);
        return WAKE_SENT;
    }];
}

+ (NSData*) createPayload:(TemporaryHost*)host {
    NSMutableData* payload = [[NSMutableData alloc] initWithCapacity:102];
    
    // 6 bytes of FF
    UInt8 header = 0xFF;
    for (int i = 0; i < 6; i++) {
        [payload appendBytes:&header length:1];
    }
    
    // 16 repitiions of MAC address
    NSData* macAddress = [self macStringToBytes:host.mac];
    for (int j = 0; j < 16; j++) {
        [payload appendData:macAddress];
    }

    return payload;
}

+ (NSData*) macStringToBytes:(NSString*)mac {
    NSString* macString = [mac stringByReplacingOccurrencesOfString:@":" withString:@""];
    Log(LOG_D, @"MAC: %@", macString);
    return [Utils hexToBytes:macString];
}

@end
