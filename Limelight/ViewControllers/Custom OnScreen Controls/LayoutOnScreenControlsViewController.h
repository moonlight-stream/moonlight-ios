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

/**
 This view controller provides the user interface which allows the user to position on screen controller buttons anywhere they'd like on the screen. It also provides the user with the abilities to undo a change, save the on screen controller layout for later retrieval, and load previously saved controller layouts
 */
@interface LayoutOnScreenControlsViewController : UIViewController 


@property LayoutOnScreenControls *layoutOSC;    // object that contains a view which contains the on screen controller buttons that allows the user to drag and positions each button on the screen using touch
@property int OSCSegmentSelected;

@property (weak, nonatomic) IBOutlet UIButton *trashCanButton;
@property (weak, nonatomic) IBOutlet UIButton *undoButton;

@property (weak, nonatomic) IBOutlet ToolBarContainerView *toolbarRootView;
@property (weak, nonatomic) IBOutlet UIView *chevronView;
@property (weak, nonatomic) IBOutlet UIImageView *chevronImageView;
@property (weak, nonatomic) IBOutlet UIStackView *toolbarStackView;



@end

NS_ASSUME_NONNULL_END
