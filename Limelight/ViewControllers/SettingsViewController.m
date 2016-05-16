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

#define BITRATE_INTERVAL 500 // in kbps

@implementation SettingsViewController {
    NSInteger _bitrate;
}
static NSString* bitrateFormat = @"Bitrate: %.1f Mbps";


- (void)viewDidLoad {
    [super viewDidLoad];
    
    DataManager* dataMan = [[DataManager alloc] init];
    TemporarySettings* currentSettings = [dataMan getSettings];
    
    // Bitrate is persisted in kbps
    _bitrate = [currentSettings.bitrate integerValue];
    NSInteger framerate = [currentSettings.framerate integerValue] == 30 ? 0 : 1;
    NSInteger resolution;
    if ([currentSettings.height integerValue] == 720) {
        resolution = 0;
    } else if ([currentSettings.height integerValue] == 1080) {
        resolution = 1;
    } else {
        resolution = 0;
    }
#if TARGET_OS_IOS
    NSInteger onscreenControls = [currentSettings.onscreenControls integerValue];
#elif TARGET_OS_TV
    NSInteger onscreenControls = 0; // no onscreen for tvOS
#endif
    [self.resolutionSelector setSelectedSegmentIndex:resolution];
    [self.resolutionSelector addTarget:self action:@selector(newResolutionFpsChosen) forControlEvents:UIControlEventValueChanged];
    [self.framerateSelector setSelectedSegmentIndex:framerate];
    [self.framerateSelector addTarget:self action:@selector(newResolutionFpsChosen) forControlEvents:UIControlEventValueChanged];
    [self.onscreenControlSelector setSelectedSegmentIndex:onscreenControls];
#if TARGET_OS_IOS
    [self.bitrateSlider setValue:(_bitrate / BITRATE_INTERVAL) animated:YES];
    [self.bitrateSlider addTarget:self action:@selector(bitrateSliderMoved) forControlEvents:UIControlEventValueChanged];
#elif TARGET_OS_TV
    [self.bitrateUpButton addTarget:self action:@selector(bitrateButtonPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
    [self.bitrateDownButton addTarget:self action:@selector(bitrateButtonPressed:) forControlEvents:UIControlEventPrimaryActionTriggered];
#endif
    [self updateBitrateText];
}

#if TARGET_OS_IOS
#elif TARGET_OS_TV
- (void) bitrateButtonPressed:(UIButton *)sender {
  Log(LOG_I, @"Pressed button %@", sender);
}
#endif
- (void) newResolutionFpsChosen {
    NSInteger frameRate = [self getChosenFrameRate];
    NSInteger resHeight = [self getChosenStreamHeight];
    NSInteger defaultBitrate;
    
    // 1080p60 is 20 Mbps
    if (frameRate == 60 && resHeight == 1080) {
        defaultBitrate = 20000;
    }
    // 720p60 and 1080p30 are 10 Mbps
    else if (frameRate == 60 || resHeight == 1080) {
        defaultBitrate = 10000;
    }
    // 720p30 is 5 Mbps
    else {
#if TARGET_OS_IOS
        defaultBitrate = 5000;
#elif TARGET_OS_TV
        defaultBitrate = 20000; // default 1080p on tvOS
#endif
    }
    
    _bitrate = defaultBitrate;
#if TARGET_OS_IOS
  [self.bitrateSlider setValue:defaultBitrate / BITRATE_INTERVAL animated:YES];
#elif TARGET_OS_TV
#endif
    [self updateBitrateText];
}

- (void) bitrateSliderMoved {
#if TARGET_OS_IOS
    _bitrate = BITRATE_INTERVAL * (int)self.bitrateSlider.value;
#elif TARGET_OS_TV
#endif
  Log(LOG_I, [NSString stringWithFormat:@"Moved Slider %ld", (long)_bitrate]);

    [self updateBitrateText];
}

- (void) updateBitrateText {
    // Display bitrate in Mbps
    [self.bitrateLabel setText:[NSString stringWithFormat:bitrateFormat, _bitrate / 1000.]];
}

- (NSInteger) getChosenFrameRate {
    return [self.framerateSelector selectedSegmentIndex] == 0 ? 30 : 60;
}

- (NSInteger) getChosenStreamHeight {
#if TARGET_OS_IOS
  return [self.resolutionSelector selectedSegmentIndex] == 0 ? 720 : 1080;
#elif TARGET_OS_TV
    return 1080; // default 1080p on tvOS
#endif
}

- (NSInteger) getChosenStreamWidth {
    return [self getChosenStreamHeight] == 720 ? 1280 : 1920;
}

- (void) saveSettings {
    DataManager* dataMan = [[DataManager alloc] init];
    NSInteger framerate = [self getChosenFrameRate];
    NSInteger height = [self getChosenStreamHeight];
    NSInteger width = [self getChosenStreamWidth];
    NSInteger onscreenControls = [self.onscreenControlSelector selectedSegmentIndex];
    [dataMan saveSettingsWithBitrate:_bitrate framerate:framerate height:height width:width onscreenControls:onscreenControls];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
}


@end
