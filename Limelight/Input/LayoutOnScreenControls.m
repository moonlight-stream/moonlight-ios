//
//  LayoutOnScreenControls.m
//  Moonlight
//
//  Created by Long Le on 9/26/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "LayoutOnScreenControls.h"
#import "OSCProfilesTableViewController.h"
#import "OnScreenButtonState.h"
#import "OSCProfilesManager.h"


@interface LayoutOnScreenControls ()
@end

@implementation LayoutOnScreenControls {
    
    UIButton *trashCanButton;
}

@synthesize layerCurrentlyBeingTouched;
@synthesize _view;
@synthesize layoutChanges;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig oscLevel:(int)oscLevel {
    _view = view;
    _view.multipleTouchEnabled = false;
  
    self = [super initWithView:view controllerSup:controllerSupport streamConfig:streamConfig];
    self._level = oscLevel;
    
//    [super setupComplexControls];   //get coordinates for button positions
    
//    [self drawButtons]; //get button widths
    
//    [self addDPad];
          
    layoutChanges = [[NSMutableArray alloc] init];  //will contain OSC button layout changes the user has made for this profile
        
    return self;
}

/* currently used to determine whether user is dragging an OSC button (of type CALayer) over the trash can with the intent of deleting that button*/
- (BOOL)isLayer:(CALayer *)layer hoveringOverButton:(UIButton *)button {
    CGRect buttonConvertedRect = [self._view convertRect:button.imageView.frame fromView:button.superview];
    
    if (CGRectIntersectsRect(layer.frame, buttonConvertedRect)) {
     
        return YES;
    }
    else {
        
        return NO;
    }
}

/* returns reference to button layer object given the button's name*/
- (CALayer*)buttonLayerFromName: (NSString*)name {
    for (CALayer *buttonLayer in self.OSCButtonLayers) {
        
        if ([buttonLayer.name isEqualToString:name]) {
            return buttonLayer;
        }
    }
    
    return nil;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    for (UITouch* touch in touches) {
        
        CGPoint touchLocation = [touch locationInView:_view];
        touchLocation = [[touch view] convertPoint:touchLocation toView:nil];
        CALayer *touchedLayer = [_view.layer hitTest:touchLocation];

        if (touchedLayer == _view.layer) { //don't let user move the background
            return;
        }
        
        if (touchedLayer == super._upButton || touchedLayer == super._downButton || touchedLayer == super._leftButton || touchedLayer == super._rightButton) { // don't let user move individual dPad buttons
            layerCurrentlyBeingTouched = super._dPadBackground;
            
        } else if (touchedLayer == self._rightStick) {  // only let user move right stick background, not the stick itself
            layerCurrentlyBeingTouched = self._rightStickBackground;
            
        } else if (touchedLayer == self._leftStick) {  // only let user move left stick background, not the stick itself
            layerCurrentlyBeingTouched = self._leftStickBackground;
            
        } else {    // let user move whatever other valid button they're touching
            layerCurrentlyBeingTouched = touchedLayer;
        }
        
        // save name and position of layer being touched in array in case user wants to undo the move later
        OnScreenButtonState *onScreenButtonState = [[OnScreenButtonState alloc] initWithButtonName:layerCurrentlyBeingTouched.name isHidden:layerCurrentlyBeingTouched.isHidden andPosition:layerCurrentlyBeingTouched.position];
        [layoutChanges addObject:onScreenButtonState];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"OSCLayoutChanged" object:self]; //  lets the view controller know whether to fade the undo button in or out depending on whether there are any further OSC layout changes the user is allowed to undo
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:_view];
    layerCurrentlyBeingTouched.position = touchLocation; //move object to touch location
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    layerCurrentlyBeingTouched = nil;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    layerCurrentlyBeingTouched = nil;
}




@end
