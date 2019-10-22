//
//  StreamView.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "ControllerSupport.h"
#import "OnScreenControls.h"

@protocol EdgeDetectionDelegate <NSObject>

- (void) edgeSwiped;

@end

@interface StreamView : OSView <UITextFieldDelegate>

@property (nonatomic, retain) IBOutlet UITextField* keyInputField;

- (void) setupStreamView:(ControllerSupport*)controllerSupport swipeDelegate:(id<EdgeDetectionDelegate>)swipeDelegate;
- (void) showOnScreenControls;
- (void) setMouseDeltaFactors:(float)x y:(float)y;
- (OnScreenControlsLevel) getCurrentOscState;

@end
