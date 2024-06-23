//
//  TemporarySettings.h
//  Moonlight
//
//  Created by Cameron Gutman on 12/1/15.
//  Copyright © 2015 Moonlight Stream. All rights reserved.
//

#import "Settings+CoreDataClass.h"
#define RELATIVE_TOUCH_MODE 0
#define NATIVE_TOUCH_MODE 1
#define ABSOLUTE_TOUCH_MODE 2


@interface TemporarySettings : NSObject

@property (nonatomic, retain) Settings * parent;

@property (nonatomic, retain) NSNumber * bitrate;
@property (nonatomic, retain) NSNumber * framerate;
@property (nonatomic, retain) NSNumber * height;
@property (nonatomic, retain) NSNumber * width;
@property (nonatomic, retain) NSNumber * audioConfig;
@property (nonatomic, retain) NSNumber * onscreenControls;
@property (nonatomic, retain) NSNumber * keyboardToggleFingers;
@property (nonatomic, retain) NSNumber * swipeExitScreenEdge;
@property (nonatomic, retain) NSNumber * swipeToExitDistance;
@property (nonatomic, retain) NSNumber * touchPointerVelocityFactor;
@property (nonatomic, retain) NSNumber * mousePointerVelocityFactor;
@property (nonatomic, retain) NSNumber * pointerVelocityModeDivider;
@property (nonatomic, retain) NSString * uniqueId;
@property (nonatomic) enum {
    CODEC_PREF_AUTO,
    CODEC_PREF_H264,
    CODEC_PREF_HEVC,
    CODEC_PREF_AV1,
} preferredCodec;
@property (nonatomic) BOOL useFramePacing;
@property (nonatomic) BOOL multiController;
@property (nonatomic) BOOL swapABXYButtons;
@property (nonatomic) BOOL playAudioOnPC;
@property (nonatomic) BOOL optimizeGames;
@property (nonatomic) BOOL enableHdr;
@property (nonatomic) BOOL btMouseSupport;
// @property (nonatomic) BOOL absoluteTouchMode;
@property (nonatomic, retain) NSNumber * touchMode;
@property (nonatomic) BOOL statsOverlay;
@property (nonatomic) BOOL liftStreamViewForKeyboard;
@property (nonatomic) BOOL showKeyboardToolbar;


- (id) initFromSettings:(Settings*)settings;

@end
