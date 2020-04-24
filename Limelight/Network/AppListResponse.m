//
//  AppListResponse.m
//  Moonlight
//
//  Created by Diego Waxemberg on 2/1/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "AppListResponse.h"
#import "TemporaryApp.h"
#import "DataManager.h"
#import <libxml2/libxml/xmlreader.h>

@implementation AppListResponse {
    NSMutableSet* _appList;
}
@synthesize data, statusCode, statusMessage;

static const char* TAG_APP = "App";
static const char* TAG_APP_TITLE = "AppTitle";
static const char* TAG_APP_ID = "ID";
static const char* TAG_HDR_SUPPORTED = "IsHdrSupported";
static const char* TAG_APP_INSTALL_PATH = "AppInstallPath";

- (void)populateWithData:(NSData *)xml {
    self.data = xml;
    _appList = [[NSMutableSet alloc] init];
    [self parseData];
}

- (void) parseData {
    xmlDocPtr docPtr = xmlParseMemory([self.data bytes], (int)[self.data length]);
    if (docPtr == NULL) {
        Log(LOG_W, @"An error occured trying to parse xml.");
        return;
    }
    
    xmlNodePtr node = xmlDocGetRootElement(docPtr);
    if (node == NULL) {
        Log(LOG_W, @"No root XML element.");
        xmlFreeDoc(docPtr);
        return;
    }
    
    xmlChar* statusStr = xmlGetProp(node, (const xmlChar*)[TAG_STATUS_CODE UTF8String]);
    if (statusStr != NULL) {
        int status = (int)[[NSString stringWithUTF8String:(const char*)statusStr] longLongValue];
        xmlFree(statusStr);
        self.statusCode = status;
    }
    
    xmlChar* statusMsgXml = xmlGetProp(node, (const xmlChar*)[TAG_STATUS_MESSAGE UTF8String]);
    NSString* statusMsg;
    if (statusMsgXml != NULL) {
        statusMsg = [NSString stringWithUTF8String:(const char*)statusMsgXml];
        xmlFree(statusMsgXml);
    }
    else {
        statusMsg = @"Server Error";
    }
    self.statusMessage = statusMsg;
    
    node = node->children;
    
    while (node != NULL) {
        //Log(LOG_D, @"node: %s", node->name);
        if (!xmlStrcmp(node->name, (xmlChar*)TAG_APP)) {
            xmlNodePtr appInfoNode = node->xmlChildrenNode;
            NSString* appName = @"";
            NSString* appId = nil;
            NSString* hdrSupported = @"0";
            NSString* appInstallPath = nil;
            while (appInfoNode != NULL) {
                if (!xmlStrcmp(appInfoNode->name, (xmlChar*)TAG_APP_TITLE)) {
                    xmlChar* nodeVal = xmlNodeListGetString(docPtr, appInfoNode->xmlChildrenNode, 1);
                    if (nodeVal != NULL) {
                        appName = [[NSString alloc] initWithCString:(const char*)nodeVal encoding:NSUTF8StringEncoding];
                        xmlFree(nodeVal);
                    }
                } else if (!xmlStrcmp(appInfoNode->name, (xmlChar*)TAG_APP_ID)) {
                    xmlChar* nodeVal = xmlNodeListGetString(docPtr, appInfoNode->xmlChildrenNode, 1);
                    if (nodeVal != NULL) {
                        appId = [[NSString alloc] initWithCString:(const char*)nodeVal encoding:NSUTF8StringEncoding];
                        xmlFree(nodeVal);
                    }
                } else if (!xmlStrcmp(appInfoNode->name, (xmlChar*)TAG_HDR_SUPPORTED)) {
                    xmlChar* nodeVal = xmlNodeListGetString(docPtr, appInfoNode->xmlChildrenNode, 1);
                    if (nodeVal != NULL) {
                        hdrSupported = [[NSString alloc] initWithCString:(const char*)nodeVal encoding:NSUTF8StringEncoding];
                        xmlFree(nodeVal);
                    }
                } else if (!xmlStrcmp(appInfoNode->name, (xmlChar*)TAG_APP_INSTALL_PATH)) {
                    xmlChar* nodeVal = xmlNodeListGetString(docPtr, appInfoNode->xmlChildrenNode, 1);
                    if (nodeVal != NULL) {
                        appInstallPath = [[NSString alloc] initWithCString:(const char*)nodeVal encoding:NSUTF8StringEncoding];
                        xmlFree(nodeVal);
                    }
                }

                appInfoNode = appInfoNode->next;
            }
            if (appId != nil) {
                TemporaryApp* app = [[TemporaryApp alloc] init];
                app.name = appName;
                app.id = appId;
                app.hdrSupported = [hdrSupported intValue] != 0;
                app.installPath = appInstallPath;
                [_appList addObject:app];
            }
        }
        node = node->next;
    }
    
    xmlFreeDoc(docPtr);
    
    // APP STORE REVIEW COMPLIANCE
    //
    // Remove default Steam entry from the app list to comply with Apple App Store Guideline 4.2.7d:
    //
    // The UI appearing on the client does not resemble an iOS or App Store view, does not provide a store-like interface,
    // or include the ability to browse, select, or purchase software not already owned or licensed by the user.
    //
    // However, if the user manually adds Steam themselves, then we will display it.
    TemporaryApp* officialSteamApp = nil;
    TemporaryApp* manuallyAddedSteamApp = nil;
    for (TemporaryApp* app in _appList) {
        if (app.installPath != nil && [[app.installPath lowercaseString] hasSuffix:@"\\steam\\"]) {
            // The official Steam app is marked as HDR supported, while manually added ones are not.
            if ([app.name isEqualToString:@"Steam"] && app.hdrSupported) {
                officialSteamApp = app;
            }
            else {
                manuallyAddedSteamApp = app;
            }
        }
    }
    
    // To be safe, don't do anything if we didn't find an HDR-enabled Steam app.
    if (officialSteamApp != nil) {
        // If we didn't find a manually added Steam app, remove the official one to
        // comply with the App Store guidelines.
        if (manuallyAddedSteamApp == nil) {
            [_appList removeObject:officialSteamApp];
        }
        else {
            [_appList removeObject:manuallyAddedSteamApp];
        }
    }
}

- (NSSet*) getAppList {
    return _appList;
}

- (BOOL) isStatusOk {
    return self.statusCode == 200;
}

@end
