//
//  LayoutOnScreenControlsViewController.h
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LayoutOnScreenControls.h"
#import "ToolBarContainerView.h"

NS_ASSUME_NONNULL_BEGIN

@interface LayoutOnScreenControlsViewController : UIViewController 


@property LayoutOnScreenControls *layoutOSC;
@property int OSCSegmentSelected;
@property (weak, nonatomic) IBOutlet ToolBarContainerView *toolbarRootView;
@property (weak, nonatomic) IBOutlet UIView *chevronView;
@property (weak, nonatomic) IBOutlet UIImageView *chevronImageView;
@property (weak, nonatomic) IBOutlet UIButton *trashCanButton;
@property (weak, nonatomic) IBOutlet UIButton *undoButton;
@property (weak, nonatomic) IBOutlet UIStackView *toolbarStackView;

@end

NS_ASSUME_NONNULL_END
