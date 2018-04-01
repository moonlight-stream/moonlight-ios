//
//  StreamView.h
//  Moonlight macOS
//
//  Created by Felix Kratz on 10.03.18.
//  Copyright (c) 2018 Felix Kratz. All rights reserved.
//

#import <AppKit/AppKit.h>

@interface StreamView : NSView

- (void)drawMessage:(NSString*)message;

@property int codec;
@property unsigned short frameCount;


@end
