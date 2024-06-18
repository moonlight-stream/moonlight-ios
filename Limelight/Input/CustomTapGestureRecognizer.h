//
//  CustomTapGestureRecognizer.h
//  Moonlight
//
//  Created by ZWM on 2024/5/15.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#ifndef CustomTapGestureRecognizer_h
#define CustomTapGestureRecognizer_h


@interface CustomTapGestureRecognizer : UIGestureRecognizer{
    CGFloat lowestTouchPointYCoord;
}


@property (nonatomic, assign) uint8_t numberOfTouchesRequired;
@property (nonatomic, assign) bool immediateTriggering; // if enabled,  trigger the signal on touchesBegan stage.
@property (nonatomic, assign) double tapDownTimeThreshold; // tap down threshold in seconds.
@property (nonatomic, readonly) CGFloat lowestTouchPointHeight;
@property (nonatomic, readonly) bool gestureCaptured;
@property (nonatomic, readonly) NSTimeInterval gestureCapturedTime;

@end
#endif /* CustomTapGestureRecognizer_h */
