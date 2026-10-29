//
//  Utils.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/20/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "Utils.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <netdb.h>

@implementation Utils
NSString *const deviceName = @"roth";

+ (NSData*) randomBytes:(NSInteger)length {
    char* bytes = malloc(length);
    arc4random_buf(bytes, length);
    NSData* randomData = [NSData dataWithBytes:bytes length:length];
    free(bytes);
    return randomData;
}

+ (NSData*) hexToBytes:(NSString*) hex {
    unsigned long len = [hex length];
    NSMutableData* data = [NSMutableData dataWithCapacity:len / 2];
    char byteChars[3] = {'\0','\0','\0'};
    unsigned long wholeByte;
    
    const char *chars = [hex UTF8String];
    int i = 0;
    while (i < len) {
        byteChars[0] = chars[i++];
        byteChars[1] = chars[i++];
        wholeByte = strtoul(byteChars, NULL, 16);
        [data appendBytes:&wholeByte length:1];
    }
    
    return data;
}

+ (NSString*) bytesToHex:(NSData*)data {
    const unsigned char* bytes = [data bytes];
    NSMutableString *hex = [[NSMutableString alloc] init];
    for (int i = 0; i < [data length]; i++) {
        [hex appendFormat:@"%02X" , bytes[i]];
    }
    return hex;
}

+ (BOOL)isActiveNetworkVPN {
    NSDictionary *dict = CFBridgingRelease(CFNetworkCopySystemProxySettings());
    NSArray *keys = [dict[@"__SCOPED__"] allKeys];
    for (NSString *key in keys) {
        if ([key containsString:@"tap"] ||
            [key containsString:@"tun"] ||
            [key containsString:@"ppp"] ||
            [key containsString:@"ipsec"]) {
            return YES;
        }
    }
    return NO;
}

#if !TARGET_OS_TV
+ (void) launchUrl:(NSString*)urlString {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString] options:@{} completionHandler:nil];
}
#endif

+ (void) addHelpOptionToDialog:(UIAlertController*)dialog {
#if !TARGET_OS_TV
    // tvOS doesn't have a browser
    [dialog addAction:[UIAlertAction actionWithTitle:@"Help" style:UIAlertActionStyleDefault handler:^(UIAlertAction* action){
        [Utils launchUrl:@"https://github.com/moonlight-stream/moonlight-docs/wiki/Troubleshooting"];
    }]];
#endif
}

+ (BOOL) parseAddressPortString:(NSString*)addressPort address:(NSRange*)address port:(NSRange*)port {
    if (![addressPort containsString:@":"]) {
        // If there's no port or IPv6 separator, the whole thing is an address
        *address = NSMakeRange(0, [addressPort length]);
        *port = NSMakeRange(NSNotFound, 0);
        return TRUE;
    }
    
    NSInteger locationOfOpeningBracket = [addressPort rangeOfString:@"["].location;
    NSInteger locationOfClosingBracket = [addressPort rangeOfString:@"]"].location;
    if (locationOfOpeningBracket != NSNotFound || locationOfClosingBracket != NSNotFound) {
        // If we have brackets, it's an IPv6 address
        if (locationOfOpeningBracket == NSNotFound || locationOfClosingBracket == NSNotFound ||
            locationOfClosingBracket < locationOfOpeningBracket) {
            // Invalid address format
            return FALSE;
        }
        
        // Cut at the brackets
        *address = NSMakeRange(locationOfOpeningBracket + 1, locationOfClosingBracket - locationOfOpeningBracket - 1);
    }
    else {
        // It's an IPv4 address, so just cut at the port separator
        *address = NSMakeRange(0, [addressPort rangeOfString:@":"].location);
    }
    
    NSUInteger remainingStringLocation = address->location + address->length;
    NSRange remainingStringRange = NSMakeRange(remainingStringLocation, [addressPort length] - remainingStringLocation);
    NSInteger locationOfPortSeparator = [addressPort rangeOfString:@":" options:0 range:remainingStringRange].location;
    if (locationOfPortSeparator != NSNotFound) {
        *port = NSMakeRange(locationOfPortSeparator + 1, [addressPort length] - locationOfPortSeparator - 1);
    }
    else {
        *port = NSMakeRange(NSNotFound, 0);
    }
    
    return TRUE;
}

+ (NSString*) addressPortStringToAddress:(NSString*)addressPort {
    NSRange addressRange, portRange;
    if (![self parseAddressPortString:addressPort address:&addressRange port:&portRange]) {
        return nil;
    }
    
    return [addressPort substringWithRange:addressRange];
}

+ (unsigned short) addressPortStringToPort:(NSString*)addressPort {
    NSRange addressRange, portRange;
    if (![self parseAddressPortString:addressPort address:&addressRange port:&portRange] || portRange.location == NSNotFound) {
        return 47989;
    }
    
    return [[addressPort substringWithRange:portRange] integerValue];
}

+ (NSString*) addressAndPortToAddressPortString:(NSString*)address port:(unsigned short)port {
    if ([address containsString:@":"]) {
        // IPv6 addresses require escaping
        return [NSString stringWithFormat:@"[%@]:%u", address, port];
    }
    else {
        return [NSString stringWithFormat:@"%@:%u", address, port];
    }
}

+ (CGSize) getDisplayResolutionForWindow:(UIWindow*)window safeArea:(BOOL)safeArea {
    if (window == nil) {
        // The caller may not be in a window yet, so use the first one we can find
        for (UIScene* scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                window = ((UIWindowScene*)scene).windows.firstObject;
                break;
            }
        }
    }

    CGFloat width = window.bounds.size.width;
    if (safeArea) {
        // The video is centered, so leave room for the larger inset on both sides
        // (the insets are one-sided on displays like those of iPhone Duo)
        width -= 2 * MAX(window.safeAreaInsets.left, window.safeAreaInsets.right);
    }

    // Use the native scale rather than the UI scale, so we match the physical pixels
    // of displays that downsample the UI (like the inner display of iPhone Duo, which
    // renders at 3x but has a 2670x1878 panel). Video encoders require even dimensions.
    CGFloat nativeScale = (window.windowScene.screen ?: window.screen).nativeScale;
    return CGSizeMake(lround(width * nativeScale) & ~1,
                      lround(window.bounds.size.height * nativeScale) & ~1);
}

@end

@implementation NSString (NSStringWithTrim)

- (NSString *)trim {
    return [self stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

@end
