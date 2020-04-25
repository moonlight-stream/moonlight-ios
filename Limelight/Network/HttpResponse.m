//
//  HttpResponse.m
//  Moonlight
//
//  Created by Diego Waxemberg on 1/30/15.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "HttpResponse.h"
#import "TemporaryApp.h"
#import <libxml2/libxml/xmlreader.h>

@implementation HttpResponse {
    NSMutableDictionary* _elements;
}
@synthesize data, statusCode, statusMessage;

- (void) populateWithData:(NSData*)xml {
    self.data = xml;
    [self parseData];
}

- (NSString*) getStringTag:(NSString*)tag {
    return [_elements objectForKey:tag];
}

- (BOOL) getIntTag:(NSString *)tag value:(NSInteger*)value {
    NSString* stringVal = [self getStringTag:tag];
    if (stringVal != nil) {
        *value = [stringVal integerValue];
        return true;
    } else {
        return false;
    }
}

- (BOOL) isStatusOk {
    return self.statusCode == 200;
}

- (void) parseData {
    _elements = [[NSMutableDictionary alloc] init];
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
    if (statusMsgXml != NULL) {
        self.statusMessage = [NSString stringWithUTF8String:(const char*)statusMsgXml];
        xmlFree(statusMsgXml);
    }
    else {
        self.statusMessage = @"Server Error";
    }
    
    if (self.statusCode == -1 && [self.statusMessage isEqualToString:@"Invalid"]) {
        // Special case handling an audio capture error which GFE doesn't
        // provide any useful status message for.
        self.statusCode = 418;
        self.statusMessage = @"Missing audio capture device. Reinstalling GeForce Experience should resolve this error.";
    }

    node = node->children;
    
    while (node != NULL) {
        xmlChar* nodeVal = xmlNodeListGetString(docPtr, node->xmlChildrenNode, 1);
        
        NSString* value;
        if (nodeVal == NULL) {
            value = @"";
        } else {
            value = [[NSString alloc] initWithCString:(const char*)nodeVal encoding:NSUTF8StringEncoding];
        }
        NSString* key = [[NSString alloc] initWithCString:(const char*)node->name encoding:NSUTF8StringEncoding];
        [_elements setObject:value forKey:key];
        xmlFree(nodeVal);
        node = node->next;
    }
    
    xmlFreeDoc(docPtr);
    
    Log(LOG_D, @"Parsed XML data: %@", _elements);
}

@end
