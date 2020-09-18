//
//  StreamFrameViewController.h
//  Moonlight
//
//  Created by Diego Waxemberg on 1/18/14.
//  Copyright (c) 2015 Moonlight Stream. All rights reserved.
//

#import "Connection.h"
#import "StreamConfiguration.h"
#import "StreamView.h"

#import <UIKit/UIKit.h>

#if TARGET_OS_TV
@import GameController;

@interface StreamFrameViewController : GCEventViewController <ConnectionCallbacks, EdgeDetectionDelegate, InputPresenceDelegate, UserInteractionDelegate>
#else
@interface StreamFrameViewController : UIViewController <ConnectionCallbacks, EdgeDetectionDelegate, InputPresenceDelegate, UserInteractionDelegate>
#endif
@property (strong, nonatomic) IBOutlet UILabel *stageLabel;
@property (strong, nonatomic) IBOutlet UILabel *tipLabel;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *spinner;
@property (nonatomic) StreamConfiguration* streamConfig;

@end
