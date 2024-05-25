//
//  CustomTapGestureRecognizer.h
//  Moonlight
//
//  Created by Admin on 2024/5/15.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#ifndef CustomTapGestureRecognizer_h
#define CustomTapGestureRecognizer_h



@interface CustomTapGestureRecognizer : UIGestureRecognizer

@property (nonatomic, assign) uint8_t numberOfTouchesRequired;
@property (nonatomic, assign) double tapDownTimeThreshold;
@property (nonatomic, readonly) CGFloat lowestTouchPointHeight;


@end
#endif /* CustomTapGestureRecognizer_h */
