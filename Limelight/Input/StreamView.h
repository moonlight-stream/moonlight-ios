//
//  StreamView.h
//  Moonlight
//
//  Created by Cameron Gutman on 10/19/14.
//  Copyright (c) 2014 Moonlight Stream. All rights reserved.
//

#import "ControllerSupport.h"
#import "OnScreenControls.h"
#import "Moonlight-Swift.h"

@protocol EdgeDetectionDelegate <NSObject>

- (void) edgeSwiped;

@end

@protocol UserInteractionDelegate <NSObject>

- (void) userInteractionBegan;
- (void) userInteractionEnded;

@end

#if TARGET_OS_TV
@interface StreamView : OSView <X1KitMouseDelegate>
#else
@interface StreamView : OSView <X1KitMouseDelegate, UIPointerInteractionDelegate>
#endif

@property (nonatomic, retain) IBOutlet UITextField* keyInputField;

- (void) setupStreamView:(ControllerSupport*)controllerSupport swipeDelegate:(id<EdgeDetectionDelegate>)swipeDelegate interactionDelegate:(id<UserInteractionDelegate>)interactionDelegate;
- (void) showOnScreenControls;
- (void) setMouseDeltaFactors:(float)x y:(float)y;
- (OnScreenControlsLevel) getCurrentOscState;

@end
