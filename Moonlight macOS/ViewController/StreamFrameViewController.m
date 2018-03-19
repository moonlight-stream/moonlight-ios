//
//  StreamFrameViewController.m
//  Moonlight macOS
//
//  Created by Felix Kratz on 09.03.18.
//  Copyright © 2018 Felix Kratz. All rights reserved.
//

#import "StreamFrameViewController.h"
#import "VideoDecoderRenderer.h"
#import "StreamManager.h"
#import "Control.h"
#import "Gamepad.h"
#import "keepAlive.h"

@interface StreamFrameViewController ()
@end

@implementation StreamFrameViewController {
    StreamManager *_streamMan;
    StreamConfiguration *_streamConfig;
    NSTimer* _timer;
    ViewController* _origin;
}

-(ViewController*) _origin {
    return _origin;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [keepAlive keepSystemAlive];
    self.streamConfig = _streamConfig;
    
    initGamepad();
    
    // The Gamepad currently gets refreshed at 60Hz, this could very well be set as 1/Framerate in the future.
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0/60.0 target:self selector:@selector(timerTick) userInfo:nil repeats:true];
    
    _streamMan = [[StreamManager alloc] initWithConfig:self.streamConfig
                                            renderView:self.view
                                   connectionCallbacks:self];
    NSOperationQueue* opQueue = [[NSOperationQueue alloc] init];
    [opQueue addOperation:_streamMan];
    // Do view setup here.
}

- (void)timerTick {
    Gamepad_processEvents();
}

- (void) viewDidAppear {
    [super viewDidAppear];
    
    // Hide the cursor and disconnect it from the mouse movement
    [NSCursor hide];
    CGAssociateMouseAndMouseCursorPosition(false);
    
    //During the setup the window should not be resizable, but to use the fullscreen feature of macOS it has to be resizable.
    [self.view.window setStyleMask:[self.view.window styleMask] | NSWindowStyleMaskResizable];
    
    if (self.view.bounds.size.height != NSScreen.mainScreen.frame.size.height || self.view.bounds.size.width != NSScreen.mainScreen.frame.size.width) {
        [self.view.window toggleFullScreen:self];
    }
    [_progressIndicator startAnimation:nil];
    [_origin dismissController:nil];
    _origin = nil;
}

-(void)viewWillDisappear {
    [NSCursor unhide];
    [keepAlive allowSleep];
    [_streamMan stopStream];
    CGAssociateMouseAndMouseCursorPosition(true);
    if (self.view.bounds.size.height == NSScreen.mainScreen.frame.size.height && self.view.bounds.size.width == NSScreen.mainScreen.frame.size.width) {
        [self.view.window toggleFullScreen:self];
        [self.view.window setStyleMask:[self.view.window styleMask] & ~NSWindowStyleMaskResizable];
    }
}

- (void)connectionStarted {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_progressIndicator stopAnimation:nil];
        _progressIndicator.hidden = true;
        _stageLabel.stringValue = @"Waiting for the first frame";
    });
}

- (void)connectionTerminated:(long)errorCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"error has occured: %ld", errorCode);
        NSStoryboard *storyBoard = [NSStoryboard storyboardWithName:@"Mac" bundle:nil];
        ViewController* view = (ViewController*)[storyBoard instantiateControllerWithIdentifier :@"setupFrameVC"];
        [view setError:1];
        self.view.window.contentViewController = view;
    });
}

- (void)setOrigin: (ViewController*) viewController
{
    _origin = viewController;
}

- (void)displayMessage:(const char *)message {
    
}

- (void)displayTransientMessage:(const char *)message {
}

- (void)launchFailed:(NSString *)message {
    
}

- (void)stageComplete:(const char *)stageName {
    
}

- (void)stageFailed:(const char *)stageName withError:(long)errorCode {
    
}

- (void)stageStarting:(const char *)stageName {
}

@end
