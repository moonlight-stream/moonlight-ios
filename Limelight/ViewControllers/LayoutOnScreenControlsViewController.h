//
//  LayoutOnScreenControlsViewController.h
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LayoutOnScreenControls.h"

NS_ASSUME_NONNULL_BEGIN

@interface LayoutOnScreenControlsViewController : UIViewController 

@property NSInteger onScreenControlSegmentSelected;
@property (weak, nonatomic) IBOutlet UIView *toolbarRootView;
@property (weak, nonatomic) IBOutlet UIView *chevronView;
@property (weak, nonatomic) IBOutlet UIImageView *chevronImageView;


@end

NS_ASSUME_NONNULL_END
