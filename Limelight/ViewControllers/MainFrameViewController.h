//
//  MainFrameViewController.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DiscoveryManager.h"
#import "PairManager.h"
#import "StreamConfiguration.h"
#import "UIComputerView.h"
#import "UIAppView.h"
#import "AppAssetManager.h"
#import "SWRevealViewController.h"

#if TARGET_OS_IOS
@interface MainFrameViewController : UICollectionViewController <DiscoveryCallback, PairCallback, HostCallback, AppCallback, AppAssetCallback, NSURLConnectionDelegate, SWRevealViewControllerDelegate>
#elif TARGET_OS_TV
@interface MainFrameViewController : UICollectionViewController <DiscoveryCallback, PairCallback, HostCallback, AppCallback, AppAssetCallback, NSURLConnectionDelegate, UICollectionViewDataSource, SWRevealViewControllerDelegate>
#endif
@property (strong, nonatomic) IBOutlet UIButton *limelightLogoButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *computerNameButton;

@end
