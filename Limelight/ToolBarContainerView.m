//
//  ToolBarContainerView.m
//  Moonlight
//
//  Created by Long Le on 12/10/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "ToolBarContainerView.h"

@implementation ToolBarContainerView

- (BOOL) pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    
    for (UIView *view in self.subviews) {
        
        if (!view.hidden && view.alpha > 0 &&
            view.userInteractionEnabled &&
            [view pointInside:[self convertPoint:point toView:view] withEvent:event])
            return YES;
        }
    
    return NO;
}

@end
