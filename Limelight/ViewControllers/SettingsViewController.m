//
//  SettingsViewController.m
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "SettingsViewController.h"
#import "TemporarySettings.h"
#import "DataManager.h"

#import <VideoToolbox/VideoToolbox.h>

@implementation SettingsViewController {
    NSInteger _bitrate;
}

@dynamic overrideUserInterfaceStyle;

static NSString* bitrateFormat = @"Bitrate: %.1f Mbps";
static const int bitrateTable[] = {
    500,
    1000,
    1500,
    2000,
    2500,
    3000,
    4000,
    5000,
    6000,
    7000,
    8000,
    9000,
    10000,
    12000,
    15000,
    18000,
    20000,
    30000,
    40000,
    50000,
    60000,
    70000,
    80000,
    100000,
    120000,
    150000,
};

const int RESOLUTION_TABLE_SIZE = 5;
const int RESOLUTION_TABLE_CUSTOM_INDEX = RESOLUTION_TABLE_SIZE - 1;
const int RESOLUTION_TABLE_DEFAULT_INDEX = 1;
CGSize resolutionTable[RESOLUTION_TABLE_SIZE];

-(int)getSliderValueForBitrate:(NSInteger)bitrate {
    int i;
    
    for (i = 0; i < (sizeof(bitrateTable) / sizeof(*bitrateTable)); i++) {
        if (bitrate <= bitrateTable[i]) {
            return i;
        }
    }
    
    // Return the last entry in the table
    return i - 1;
}

-(void)viewDidLayoutSubviews {
    // On iPhone layouts, this view is rooted at a ScrollView. To make it
    // scrollable, we'll update content size here.
    if (self.scrollView != nil) {
        CGFloat highestViewY = 0;
        
        // Enumerate the scroll view's subviews looking for the
        // highest view Y value to set our scroll view's content
        // size.
        for (UIView* view in self.scrollView.subviews) {
            // UIScrollViews have 2 default child views
            // which represent the horizontal and vertical scrolling
            // indicators. Ignore any views we don't recognize.
            if (![view isKindOfClass:[UILabel class]] &&
                ![view isKindOfClass:[UISegmentedControl class]] &&
                ![view isKindOfClass:[UISlider class]]) {
                continue;
            }
            
            CGFloat currentViewY = view.frame.origin.y + view.frame.size.height;
            if (currentViewY > highestViewY) {
                highestViewY = currentViewY;
            }
        }
        
        // Add a bit of padding so the view doesn't end right at the button of the display
        self.scrollView.contentSize = CGSizeMake(self.scrollView.contentSize.width,
                                                 highestViewY + 20);
    }
}

// Adjust the subviews for the safe area on the iPhone X.
- (void)viewSafeAreaInsetsDidChange {
    [super viewSafeAreaInsetsDidChange];
    
    if (@available(iOS 11.0, *)) {
        for (UIView* view in self.view.subviews) {
            // HACK: The official safe area is much too large for our purposes
            // so we'll just use the presence of any safe area to indicate we should
            // pad by 20.
            if (self.view.safeAreaInsets.left >= 20 || self.view.safeAreaInsets.right >= 20) {
                view.frame = CGRectMake(view.frame.origin.x + 20, view.frame.origin.y, view.frame.size.width, view.frame.size.height);
            }
        }
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Always run settings in dark mode because we want the light fonts
    if (@available(iOS 13.0, tvOS 13.0, *)) {
        self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* currentSettings = [dataMan getSettings];
    
    // Ensure we pick a bitrate that falls exactly onto a slider notch
    _bitrate = bitrateTable[[self getSliderValueForBitrate:[currentSettings.bitrate intValue]]];

    resolutionTable[0] = CGSizeMake(640, 360);
    resolutionTable[1] = CGSizeMake(1280, 720);
    resolutionTable[2] = CGSizeMake(1920, 1080);
    resolutionTable[3] = CGSizeMake(3840, 2160);
    resolutionTable[4] = CGSizeMake([currentSettings.width integerValue], [currentSettings.height integerValue]); // custom initial value

    NSInteger framerate;
    switch ([currentSettings.framerate integerValue]) {
        case 30:
            framerate = 0;
            break;
        default:
        case 60:
            framerate = 1;
            break;
        case 120:
            framerate = 2;
            break;
    }

    NSInteger resolution = RESOLUTION_TABLE_DEFAULT_INDEX;
    for (int i = 0; i < RESOLUTION_TABLE_SIZE; i++) {
        if ((int) resolutionTable[i].height == [currentSettings.height intValue]
            && (int) resolutionTable[i].width == [currentSettings.width intValue]) {
            resolution = i;
            break;
        }
    }

    // Only show the 120 FPS option if we have a > 60-ish Hz display
    bool enable120Fps = false;
    if (@available(iOS 10.3, tvOS 10.3, *)) {
        if ([UIScreen mainScreen].maximumFramesPerSecond > 62) {
            enable120Fps = true;
        }
    }
    if (!enable120Fps) {
        [self.framerateSelector removeSegmentAtIndex:2 animated:NO];
    }
    
    // Only show the 4K option for "recent" devices. We'll judge that by whether
    // they support HEVC decoding (A9 or later).
    if (@available(iOS 11.0, tvOS 11.0, *)) {
        if (!VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
            [self.resolutionSelector removeSegmentAtIndex:3 animated:NO];
            if (resolution >= 3) resolution--;
        }
    }
    else {
        [self.resolutionSelector removeSegmentAtIndex:3 animated:NO];
        if (resolution >= 3) resolution--;
    }

    // Disable the HEVC selector if HEVC is not supported by the hardware
    // or the version of iOS. See comment in Connection.m for reasoning behind
    // the iOS 11.3 check.
    if (@available(iOS 11.3, tvOS 11.3, *)) {
        if (VTIsHardwareDecodeSupported(kCMVideoCodecType_HEVC)) {
            [self.hevcSelector setSelectedSegmentIndex:currentSettings.useHevc ? 1 : 0];
        }
        else {
            [self.hevcSelector removeAllSegments];
            [self.hevcSelector insertSegmentWithTitle:@"Unsupported on this device" atIndex:0 animated:NO];
            [self.hevcSelector setEnabled:NO];
        }
    }
    else {
        [self.hevcSelector removeAllSegments];
        [self.hevcSelector insertSegmentWithTitle:@"Requires iOS 11.3 or later" atIndex:0 animated:NO];
        [self.hevcSelector setEnabled:NO];
    }
    
    [self.touchModeSelector setSelectedSegmentIndex:currentSettings.absoluteTouchMode ? 1 : 0];
    [self.touchModeSelector addTarget:self action:@selector(touchModeChanged) forControlEvents:UIControlEventValueChanged];
    [self.statsOverlaySelector setSelectedSegmentIndex:currentSettings.statsOverlay ? 1 : 0];
    [self.btMouseSelector setSelectedSegmentIndex:currentSettings.btMouseSupport ? 1 : 0];
    [self.optimizeSettingsSelector setSelectedSegmentIndex:currentSettings.optimizeGames ? 1 : 0];
    [self.multiControllerSelector setSelectedSegmentIndex:currentSettings.multiController ? 1 : 0];
    [self.audioOnPCSelector setSelectedSegmentIndex:currentSettings.playAudioOnPC ? 1 : 0];
    NSInteger onscreenControls = [currentSettings.onscreenControls integerValue];
    [self.resolutionSelector setSelectedSegmentIndex:resolution];
    [self.resolutionSelector addTarget:self action:@selector(newResolutionChosen) forControlEvents:UIControlEventValueChanged];
    [self.framerateSelector setSelectedSegmentIndex:framerate];
    [self.framerateSelector addTarget:self action:@selector(updateBitrate) forControlEvents:UIControlEventValueChanged];
    [self.onscreenControlSelector setSelectedSegmentIndex:onscreenControls];
    [self.onscreenControlSelector setEnabled:!currentSettings.absoluteTouchMode];
    [self.bitrateSlider setMinimumValue:0];
    [self.bitrateSlider setMaximumValue:(sizeof(bitrateTable) / sizeof(*bitrateTable)) - 1];
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:YES];
    [self.bitrateSlider addTarget:self action:@selector(bitrateSliderMoved) forControlEvents:UIControlEventValueChanged];
    [self updateBitrateText];
    [self updateCustomResolutionText];
}

- (void) touchModeChanged {
    // Disable on-screen controls in absolute touch mode
    [self.onscreenControlSelector setEnabled:[self.touchModeSelector selectedSegmentIndex] == 0];
}

- (void) updateBitrate {
    NSInteger fps = [self getChosenFrameRate];
    NSInteger width = [self getChosenStreamWidth];
    NSInteger height = [self getChosenStreamHeight];
    NSInteger defaultBitrate;
    
    // This table prefers 16:10 resolutions because they are
    // only slightly more pixels than the 16:9 equivalents, so
    // we don't want to bump those 16:10 resolutions up to the
    // next 16:9 slot.
    //
    // This logic is shamelessly stolen from Moonlight Qt:
    // https://github.com/moonlight-stream/moonlight-qt/blob/master/app/settings/streamingpreferences.cpp
    
    if (width * height <= 640 * 360) {
        defaultBitrate = 1000 * (fps / 30.0);
    }
    // This covers 1280x720 and 1280x800 too
    else if (width * height <= 1366 * 768) {
        defaultBitrate = 5000 * (fps / 30.0);
    }
    else if (width * height <= 1920 * 1200) {
        defaultBitrate = 10000 * (fps / 30.0);
    }
    else if (width * height <= 2560 * 1600) {
        defaultBitrate = 20000 * (fps / 30.0);
    }
    else /* if (width * height <= 3840 * 2160) */ {
        defaultBitrate = 40000 * (fps / 30.0);
    }
    
    // We should always be exactly on a slider position with default bitrates
    _bitrate = MIN(defaultBitrate, 100000);
    assert(bitrateTable[[self getSliderValueForBitrate:_bitrate]] == _bitrate);
    [self.bitrateSlider setValue:[self getSliderValueForBitrate:_bitrate] animated:YES];
    
    [self updateBitrateText];
}

- (void) newResolutionChosen {
    BOOL lastSegmentSelected = [self.resolutionSelector selectedSegmentIndex] + 1 == [self.resolutionSelector numberOfSegments];
    if (lastSegmentSelected) {
        [self promptCustomResolutionDialog];
    }
    [self updateBitrate];
}

- (void) promptCustomResolutionDialog {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle: @"Custom resolution" message: @"Choose a custom width and height" preferredStyle:UIAlertControllerStyleAlert];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"width ex: 1920";
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%d", (int) resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width];
    }];

    [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"height ex: 1080";
        textField.clearButtonMode = UITextFieldViewModeAlways;
        textField.borderStyle = UITextBorderStyleRoundedRect;
        textField.keyboardType = UIKeyboardTypeNumberPad;
        textField.text = [NSString stringWithFormat:@"%d", (int) resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height];
    }];

    [alertController addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray * textfields = alertController.textFields;
        UITextField *widthField = textfields[0];
        UITextField *heightField = textfields[1];

        resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX] = CGSizeMake(
            [widthField.text integerValue],
            [heightField.text integerValue]
        );
        [self updateBitrate];
        [self updateCustomResolutionText];
    }]];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self.resolutionSelector setSelectedSegmentIndex:RESOLUTION_TABLE_DEFAULT_INDEX];
        [self updateBitrate];
    }]];

    [self presentViewController:alertController animated:YES completion:nil];
}

- (void) updateCustomResolutionText {
    BOOL customResolutionEqualsDefaultResolution = resolutionTable[RESOLUTION_TABLE_DEFAULT_INDEX].width == resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width && resolutionTable[RESOLUTION_TABLE_DEFAULT_INDEX].height == resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height;
    
    if (!customResolutionEqualsDefaultResolution) {
        NSString *newTitle = [NSString stringWithFormat:@"Custom %dx%d", (int) resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width, (int) resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height];
        [self.resolutionSelector setTitle:newTitle forSegmentAtIndex:[self.resolutionSelector numberOfSegments] - 1];
        self.resolutionSelector.apportionsSegmentWidthsByContent = YES; // to update the width
    }
}

- (void) bitrateSliderMoved {
    assert(self.bitrateSlider.value < (sizeof(bitrateTable) / sizeof(*bitrateTable)));
    _bitrate = bitrateTable[(int)self.bitrateSlider.value];
    [self updateBitrateText];
}

- (void) updateBitrateText {
    // Display bitrate in Mbps
    [self.bitrateLabel setText:[NSString stringWithFormat:bitrateFormat, _bitrate / 1000.]];
}

- (NSInteger) getChosenFrameRate {
    switch ([self.framerateSelector selectedSegmentIndex]) {
        case 0:
            return 30;
        case 1:
            return 60;
        case 2:
            return 120;
        default:
            abort();
    }
}

- (NSInteger) getChosenStreamHeight {
    // because the 4k resolution can be removed
    BOOL lastSegmentSelected = [self.resolutionSelector selectedSegmentIndex] + 1 == [self.resolutionSelector numberOfSegments];
    if (lastSegmentSelected) {
        return resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].height;
    }

    return resolutionTable[[self.resolutionSelector selectedSegmentIndex]].height;
}

- (NSInteger) getChosenStreamWidth {
    // because the 4k resolution can be removed
    BOOL lastSegmentSelected = [self.resolutionSelector selectedSegmentIndex] + 1 == [self.resolutionSelector numberOfSegments];
    if (lastSegmentSelected) {
        return resolutionTable[RESOLUTION_TABLE_CUSTOM_INDEX].width;
    }

    return resolutionTable[[self.resolutionSelector selectedSegmentIndex]].width;
}

- (void) saveSettings {
    DataManager* dataMan = [[DataManager alloc] init];
    NSInteger framerate = [self getChosenFrameRate];
    NSInteger height = [self getChosenStreamHeight];
    NSInteger width = [self getChosenStreamWidth];
    NSInteger onscreenControls = [self.onscreenControlSelector selectedSegmentIndex];
    BOOL optimizeGames = [self.optimizeSettingsSelector selectedSegmentIndex] == 1;
    BOOL multiController = [self.multiControllerSelector selectedSegmentIndex] == 1;
    BOOL audioOnPC = [self.audioOnPCSelector selectedSegmentIndex] == 1;
    BOOL useHevc = [self.hevcSelector selectedSegmentIndex] == 1;
    BOOL btMouseSupport = [self.btMouseSelector selectedSegmentIndex] == 1;
    BOOL absoluteTouchMode = [self.touchModeSelector selectedSegmentIndex] == 1;
    BOOL statsOverlay = [self.statsOverlaySelector selectedSegmentIndex] == 1;
    [dataMan saveSettingsWithBitrate:_bitrate
                           framerate:framerate
                              height:height
                               width:width
                    onscreenControls:onscreenControls
                       optimizeGames:optimizeGames
                     multiController:multiController
                           audioOnPC:audioOnPC
                             useHevc:useHevc
                           enableHdr:NO
                      btMouseSupport:btMouseSupport
                   absoluteTouchMode:absoluteTouchMode
                        statsOverlay:statsOverlay];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}


@end
