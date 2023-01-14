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
    UIView *horizontalGuideline;
    UIView *verticalGuideline;
}

@synthesize layerBeingDragged;
@synthesize _view;
@synthesize layoutChanges;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig oscLevel:(int)oscLevel {
    _view = view;
    _view.multipleTouchEnabled = false;
  
    self = [super initWithView:view controllerSup:controllerSupport streamConfig:streamConfig];
    self._level = oscLevel;

    layoutChanges = [[NSMutableArray alloc] init];  // will contain OSC button layout changes the user has made for this profile
            
    [self drawButtons];
    [self drawGuidelines];  // add the blue guidelines that appear when button is being tapped and dragged
    
    return self;
}

#pragma mark - Drawing

/**
 * This method overrides the superclass's drawButtons method. The purpose of this method is to create a dPad parent layer, and add the four dPad buttons to it so that the user can drag the entire dPad around, directional buttons and all, as one unit as is the expected behavior. Note that we do not want the four dPad buttons to be child layers of a CALayer parent layer on the game stream view since the touch logic implemented for the four dPad buttons on the game stream view is written assuming the dPad buttons are not children of another parent CALayer
 */
- (void) drawButtons {
    [super setDPadCenter];    // Set custom position for D-Pad here
    [super setAnalogStickPositions]; // Set custom position for analog sticks here
    [super drawButtons];
    
    UIImage* downButtonImage = [UIImage imageNamed:@"DownButton"];
    UIImage* rightButtonImage = [UIImage imageNamed:@"RightButton"];
    UIImage* upButtonImage = [UIImage imageNamed:@"UpButton"];
    UIImage* leftButtonImage = [UIImage imageNamed:@"LeftButton"];
    
    //  create dPad background layer
    self._dPadBackground = [CALayer layer];
    self._dPadBackground.name = @"dPad";
    self._dPadBackground.frame = CGRectMake(self.D_PAD_CENTER_X,
                                      self.D_PAD_CENTER_Y,
                                      self._leftButton.frame.size.width * 2 + BUTTON_DIST,
                                      self._leftButton.frame.size.width * 2 + BUTTON_DIST);
    self._dPadBackground.position = CGPointMake(self.D_PAD_CENTER_X, self.D_PAD_CENTER_Y);    // since dPadBackground's dimensions have change after settings its width and height you need to reset its position again here
    [self.OSCButtonLayers addObject:self._dPadBackground];
    [_view.layer addSublayer:self._dPadBackground];

    //  add dPad buttons to parent layer
    [self._dPadBackground addSublayer:self._downButton];
    [self._dPadBackground addSublayer:self._rightButton];
    [self._dPadBackground addSublayer:self._upButton];
    [self._dPadBackground addSublayer:self._leftButton];

    /* reposition each dPad button within their parent dPadBackground layer */
    self._downButton.frame = CGRectMake(self._dPadBackground.frame.size.width/3, self._dPadBackground.frame.size.height/2 + D_PAD_DIST, downButtonImage.size.width, downButtonImage.size.height);
    self._rightButton.frame = CGRectMake(self._dPadBackground.frame.size.width/2 + D_PAD_DIST, self._dPadBackground.frame.size.height/3, rightButtonImage.size.width, rightButtonImage.size.height);
    self._upButton.frame = CGRectMake(self._dPadBackground.frame.size.width/3, 0, upButtonImage.size.width, upButtonImage.size.height);
    self._leftButton.frame = CGRectMake(0, self._dPadBackground.frame.size.height/3, leftButtonImage.size.width, leftButtonImage.size.height);
}

/**
 * draws a horizontal and vertical line that is made visible and positioned over whichever button the user is dragging around the screen
 */
- (void) drawGuidelines {
    horizontalGuideline = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self._view.frame.size.width * 2, 2)];
    horizontalGuideline.backgroundColor = [UIColor blueColor];
    horizontalGuideline.hidden = YES;
    [self._view addSubview: horizontalGuideline];
    
    verticalGuideline = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 2, self._view.frame.size.height * 2)];
    verticalGuideline.backgroundColor = [UIColor blueColor];
    verticalGuideline.hidden = YES;
    [self._view addSubview: verticalGuideline];
}


#pragma mark - Queries

/* used to determine whether user is dragging an OSC button (of type CALayer) over the trash can with the intent of hiding that button */
- (BOOL) isLayer:(CALayer *)layer hoveringOverButton:(UIButton *)button {
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

#pragma mark - Touch 

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Reset variables related to on screen controller button drag and drop routine. These variables should be reset in 'touchesCancelled' or 'touchesEnded' but these may not be called in unaccounted-for edge cases such as when the user opens various OS-level control center related views by dragging down from the top of the screen, or dragging up from the bottom of the screen. Since Apple likes to add new control centers and new ways of opening them (i.e. Dynamic Island on iPhone 14 Pro) it's best to reset these variables here when the user is beginning a new on screen controller button drag routine  */
    layerBeingDragged = nil;
    horizontalGuideline.backgroundColor = [UIColor blueColor];
    verticalGuideline.backgroundColor = [UIColor blueColor];
    
    for (UITouch* touch in touches) {   // Process touch 
        
        CGPoint touchLocation = [touch locationInView:_view];
        touchLocation = [[touch view] convertPoint:touchLocation toView:nil];
        CALayer *layer = [_view.layer hitTest:touchLocation];
        
        /* Don't let user drag and move anything other than on screen controller buttons, which are CALayer types. The reason is that 'LayoutOnScreenControls' should only be responsible for managing and letting users move on screen controller buttons. Since this class's view is currently set to be set equal to the 'LayoutOnScreenControlsViewController' view it belongs to, we need to make sure touches on the VC's objects don't propagate down to 'LayoutOnScreenControls. Weird stuff can happen to the UI buttons (trash can button, undo button, save button, etc) and other objects that belong to that VC, such as them being dragged around the screen with the user's touches */
        for (UIView *subview in self._view.subviews) {
            
            if (CGRectContainsPoint(subview.frame, touchLocation)) {
                if (![subview isKindOfClass:[CALayer class]]) {
                    return;
                }
            }
        }
   
        if (layer == self._upButton ||
            layer == self._downButton ||
            layer == self._leftButton ||
            layer == self._rightButton) { // don't let user drag individual dPad buttons
            layerBeingDragged = self._dPadBackground;
        }
        else if (layer == self._rightStick) {  // only let user drag right stick's background, not the inner analog stick itself
            layerBeingDragged = self._rightStickBackground;
        }
        else if (layer == self._leftStick) {  // only let user drag left stick's background, not the inner analog stick itself
            layerBeingDragged = self._leftStickBackground;
        }
        else {    // let user drag whatever other valid button they're touching
            layerBeingDragged = layer;
        }
        
        /* save the name and position of layer being touched in array in case user wants to undo the change later */
        OnScreenButtonState *onScreenButtonState = [[OnScreenButtonState alloc] initWithButtonName:layerBeingDragged.name isHidden:layerBeingDragged.isHidden andPosition:layerBeingDragged.position];
        [layoutChanges addObject:onScreenButtonState];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"OSCLayoutChanged" object:self]; // lets the view controller know whether to fade the undo button in or out depending on whether there are any further OSC layout changes the user is allowed to undo
        
        /* make guide lines visible and position them over the button the user is touching */
        horizontalGuideline.center = layerBeingDragged.position;
        horizontalGuideline.hidden = NO;
        verticalGuideline.center = layerBeingDragged.position;
        verticalGuideline.hidden = NO;
    }
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:_view];
    
    layerBeingDragged.position = touchLocation; // move object to touch location
    
    /* have guidelines follow wherever the user is touching on the screen */
    horizontalGuideline.center = layerBeingDragged.position;
    verticalGuideline.center = layerBeingDragged.position;
    
    /*
     Telegraph to the user whether the horizontal and/or vertical guidelines line up with one or more of the buttons on screen by doing the following:
     -Change horizontal guideline color to white if its y-position is almost equal to that of one of the buttons on screen.
     -Change vertical guideline color to white if its x-position is almost equal to that of one of the buttons on screen.
     */
    for (CALayer *button in self.OSCButtonLayers) { // horizontal guideline position check
        
        if ((layerBeingDragged != button) && !button.isHidden) {
            if ((horizontalGuideline.center.y < button.position.y + 1) &&
                (horizontalGuideline.center.y > button.position.y - 1)) {
                horizontalGuideline.backgroundColor = [UIColor whiteColor];
                break;
            }
        }
        
        horizontalGuideline.backgroundColor = [UIColor blueColor]; // change horizontal guideline back to blue if it doesn't line up with one of the on screen buttons
    }
    for (CALayer *button in self.OSCButtonLayers) { // vertical guideline position check
        
        if ((layerBeingDragged != button) && !button.isHidden) {
            if ((verticalGuideline.center.x < button.position.x + 1) &&
                (verticalGuideline.center.x > button.position.x - 1)) {
                verticalGuideline.backgroundColor = [UIColor whiteColor];
                break;
            }
        }
        
        verticalGuideline.backgroundColor = [UIColor blueColor]; // change vertical guideline back to blue if it doesn't line up with one of the on screen buttons
    }
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {
    layerBeingDragged = nil;
         
    horizontalGuideline.hidden = YES;
    verticalGuideline.hidden = YES;
    horizontalGuideline.backgroundColor = [UIColor blueColor];
    verticalGuideline.backgroundColor = [UIColor blueColor];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    layerBeingDragged = nil;
    
    horizontalGuideline.hidden = YES;
    verticalGuideline.hidden = YES;
    horizontalGuideline.backgroundColor = [UIColor blueColor];
    verticalGuideline.backgroundColor = [UIColor blueColor];
}




@end
