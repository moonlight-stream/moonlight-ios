//
//  CustomEdgeSwipeGestureRecognizer.h
//  Moonlight-ZWM
//
//  Created by ZWM on 2024/4/30.
//  Copyright © 2024 Moonlight Game Streaming Project. All rights reserved.
//

#ifndef CustomEdgeSwipeGestureRecognizer_h
#define CustomEdgeSwipeGestureRecognizer_h
// CustomEdgeSwipeGestureRecognizer.h
#import <UIKit/UIKit.h>

@interface CustomEdgeSwipeGestureRecognizer : UIGestureRecognizer

@property (nonatomic, assign) UIRectEdge edges; // Specify the edge(s) you want to recognize the swipe gesture on
@property (nonatomic, assign) CGFloat normalizedThresholdDistance; // Distance from the edge to start recognizing the gesture

@end
#endif /* CustomEdgeSwipeGestureRecognizer_h */
