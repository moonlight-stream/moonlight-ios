//
//  SettingsViewController.h
//  Moonlight
//
//  Created by Diego Waxemberg on 10/27/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AppDelegate.h"

@interface SettingsViewController : UIViewController
@property (strong, nonatomic) IBOutlet UILabel *bitrateLabel;
#if TARGET_OS_IOS
@property (strong, nonatomic) IBOutlet UISlider *bitrateSlider;
#elif TARGET_OS_TV
@property (strong, nonatomic) IBOutlet UIButton *bitrateDownButton;
@property (strong, nonatomic) IBOutlet UIButton *bitrateUpButton;
#endif
@property (strong, nonatomic) IBOutlet UISegmentedControl *framerateSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *resolutionSelector;
@property (strong, nonatomic) IBOutlet UISegmentedControl *onscreenControlSelector;

- (void) saveSettings;

@end
