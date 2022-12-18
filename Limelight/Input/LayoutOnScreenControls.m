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

@interface LayoutOnScreenControls ()
@end

@implementation LayoutOnScreenControls {
    
    CALayer *dPadBackground;    //dPad buttons moved onto here so user can drag them around the screen together
    UIButton *trashCanButton;
    CALayer *upButton;
    CALayer *downButton;
    CALayer *leftButton;
    CALayer *rightButton;
}

@synthesize layerCurrentlyBeingTouched;
@synthesize _view;
@synthesize buttonStateHistory;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig oscLevel:(int)oscLevel {
    
    _view = view;
    _view.multipleTouchEnabled = false;
  
    self = [super initWithView:view controllerSup:controllerSupport streamConfig:streamConfig];
    self._level = oscLevel;
    
    [super setupComplexControls];   //get coordinates for button positions
    
    [self drawButtons]; //get button widths
    
    [self addDPadBackground];
    [self addDPadButtonsToDPadBackgroundLayer];
          
    buttonStateHistory = [[NSMutableArray alloc] init];
                
    return self;
}

- (void)addDPadBackground {
    
    if (dPadBackground == nil) {
        
        dPadBackground = [CALayer layer];
        dPadBackground.name = @"dPadBackgroundForOSCLayoutScreen";
        dPadBackground.frame = CGRectMake(self.D_PAD_CENTER_X, self.D_PAD_CENTER_Y
                                          , self._leftButton.frame.size.width * 2.5, self._leftButton.frame.size.height * 3);
        dPadBackground.position = CGPointMake(self.D_PAD_CENTER_X, self.D_PAD_CENTER_Y);
        [self.OSCButtonLayers addObject:dPadBackground];
        
        [self._view.layer addSublayer:dPadBackground];
    }
}

- (void) addDPadButtonsToDPadBackgroundLayer {

    // create Down button
    UIImage* downButtonImage = [UIImage imageNamed:@"DownButton"];
    downButton = [CALayer layer];
    downButton.frame = CGRectMake(dPadBackground.frame.size.width/3, dPadBackground.frame.size.height/1.7, downButtonImage.size.width, downButtonImage.size.height);
    downButton.contents = (id) downButtonImage.CGImage;
    [dPadBackground addSublayer:downButton];
    
    // create Right button
    UIImage* rightButtonImage = [UIImage imageNamed:@"RightButton"];
    rightButton = [CALayer layer];
    rightButton.frame = CGRectMake(dPadBackground.frame.size.width/1.7, dPadBackground.frame.size.height/3, rightButtonImage.size.width, rightButtonImage.size.height);
    rightButton.contents = (id) rightButtonImage.CGImage;
    [dPadBackground addSublayer:rightButton];

    // create Up button
    UIImage* upButtonImage = [UIImage imageNamed:@"UpButton"];
    upButton = [CALayer layer];
    upButton.contents = (id) upButtonImage.CGImage;
    [dPadBackground addSublayer:upButton];
    upButton.frame = CGRectMake(dPadBackground.frame.size.width/3, upButton.frame.size.height, upButtonImage.size.width, upButtonImage.size.height);
    
    // create Left button
    UIImage* leftButtonImage = [UIImage imageNamed:@"LeftButton"];
    leftButton = [CALayer layer];
    leftButton.frame = CGRectMake(leftButton.frame.size.width/1.7, dPadBackground.frame.size.height/3, leftButtonImage.size.width, leftButtonImage.size.height);
    leftButton.contents = (id) leftButtonImage.CGImage;
    [dPadBackground addSublayer:leftButton];
}

/* used to determine whether user is dragging a button over the trash can with the intent of deleting that button*/
- (BOOL)isLayer:(CALayer *)layer hoveringOverButton:(UIButton *)button {
    
    CGRect trashCanFrameInViewController = [self._view convertRect:button.imageView.frame fromView:button.superview];
    
    if (CGRectIntersectsRect(layer.frame, trashCanFrameInViewController)) {
     
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

- (void)layoutOnScreenButtonsAfterUndo {
    
    buttonStateHistory = [[NSMutableArray alloc] init];
    [buttonStateHistory addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:@"buttonStatesHistoryArray"]];
    
    for (NSData *buttonStateHistoryDataObject in buttonStateHistory) {
        
        OnScreenButtonState *onScreenButtonState = [NSKeyedUnarchiver unarchivedObjectOfClass:[OnScreenButtonState class] fromData:buttonStateHistoryDataObject error:nil];
        
        for (CALayer *buttonLayer in self.OSCButtonLayers) {
            
            if ([buttonLayer.name isEqualToString:onScreenButtonState.name]) {
                
                buttonLayer.position = onScreenButtonState.position;
            }
        }
    }
}

/* Saves the last OSC layout change the user made. The record of changes is used to allow user to undo prior changes*/
- (void)saveButtonStateToHistory {
    
    NSMutableArray *buttonStateHistoryDataObjects = [[NSMutableArray alloc] init];  //will contain encoded button state objects which are a record of OSC layout changes the user made for the current profile
    
    for (OnScreenButtonState *buttonState in buttonStateHistory) {
        
        NSData *buttonStateHistoryDataObject = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [buttonStateHistoryDataObjects addObject: buttonStateHistoryDataObject];
    }
        
    NSString *profile = [[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"];
    
    [[NSUserDefaults standardUserDefaults] setObject:buttonStateHistoryDataObjects forKey:[NSString stringWithFormat:@"%@-buttonStateHistoryDataObjectsArray", profile]];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"OSCLayoutHistoryChanged" object:self];
}

- (void)loadButtonHistory {    //Loads this profile's button-change history into an array to be used in case the user wants to tap 'undo'

    [buttonStateHistory removeAllObjects];
    
    NSString *selectedOSCProfile = [[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"];

    if (selectedOSCProfile != nil) {

        NSMutableArray *buttonStatesHistoryDataObjectsArray = [[NSMutableArray alloc] init];
        [buttonStatesHistoryDataObjectsArray addObjectsFromArray:[[NSUserDefaults standardUserDefaults] objectForKey:[NSString stringWithFormat:@"%@-buttonStateHistoryDataObjectsArray", selectedOSCProfile]]];

        for (NSData *buttonStateHistoryDataObject in buttonStatesHistoryDataObjectsArray) {

            OnScreenButtonState *onScreenButtonState = [NSKeyedUnarchiver unarchivedObjectOfClass:[OnScreenButtonState class] fromData:buttonStateHistoryDataObject error:nil];
            [buttonStateHistory addObject:onScreenButtonState];
        }
    }
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
 
    for (UITouch* touch in touches) {
        
        CGPoint touchLocation = [touch locationInView:_view];
        touchLocation = [[touch view] convertPoint:touchLocation toView:nil];
        CALayer *layer = [_view.layer hitTest:touchLocation];

        if (layer == _view.layer) { //don't let user move the background
            return;
        }
        
        if (layer == upButton || layer == downButton || layer == leftButton || layer == rightButton) { // don't let user move individual dPad buttons
            
            layerCurrentlyBeingTouched = dPadBackground;
            
        } else if (layer == self._rightStick) {  // only let user move right stick background, not the stick itself
            
            layerCurrentlyBeingTouched = self._rightStickBackground;
            
            
        } else if (layer == self._leftStick) {  // only let user move left stick background, not the stick itself
            
            layerCurrentlyBeingTouched = self._leftStickBackground;
            
        } else {    // let user move whatever other valid button they're touching
            
            layerCurrentlyBeingTouched = layer;
        }
        
        // save button's position in array for use in case user wants to undo the move later
        OnScreenButtonState *onScreenButtonState = [[OnScreenButtonState alloc] initWithButtonName:layerCurrentlyBeingTouched.name isHidden:layerCurrentlyBeingTouched.isHidden andPosition:layerCurrentlyBeingTouched.position];
        [buttonStateHistory addObject:onScreenButtonState];
        
        [self saveButtonStateToHistory];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
        
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:_view];
    
    if ([layerCurrentlyBeingTouched.superlayer.delegate isKindOfClass:[UIButton class]]) { //dont let user move the trashcan, undo, or exit buttons
        return;
    }
    
    layerCurrentlyBeingTouched.position = touchLocation; //move object to touch location
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {

    layerCurrentlyBeingTouched = nil;
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    layerCurrentlyBeingTouched = nil;
}




@end
