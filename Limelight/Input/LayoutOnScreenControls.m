//
//  LayoutOnScreenControls.m
//  Moonlight
//
//  Created by Long Le on 9/26/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "LayoutOnScreenControls.h"
#import "OnScreenButtonState.h"

@interface LayoutOnScreenControls ()
@end

@implementation LayoutOnScreenControls {
    
    CALayer *layerCurrentlyBeingTouched;
    CALayer *dPadBackground;    //groups dPad buttons so they move together
    UIButton *trashCanButton;
    UIButton *undoButton;
    NSMutableArray *buttonStatesHistoryArray;
    NSMutableArray *currentButtonStatesArray;
    CALayer *upButton;
    CALayer *downButton;
    CALayer *leftButton;
    CALayer *rightButton;
}

@synthesize _view;

- (id) initWithView:(UIView*)view controllerSup:(ControllerSupport*)controllerSupport streamConfig:(StreamConfiguration*)streamConfig oscLevel:(int)oscLevel {
    
    _view = view;
    _view.multipleTouchEnabled = false;
  
    self = [super initWithView:view controllerSup:controllerSupport streamConfig:streamConfig];
    self._level = oscLevel;
    
    [super setupComplexControls];   //get coordinates for button positions
    
    [self drawButtons]; //get button widths
    
    [self addDPadBackground];
    [self addDPadButtonsToDPadBackgroundLayer];
      
    trashCanButton = (UIButton *)[self._view viewWithTag: 20];
    
    undoButton = (UIButton *)[self._view viewWithTag: 30];
    [undoButton addTarget:self action:@selector(undoButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    
    buttonStatesHistoryArray = [[NSMutableArray alloc] init];
    
    currentButtonStatesArray = [[NSMutableArray alloc] init];
    
    [self populateButtonHistoryStates];
    
    [self populateCurrentButtonStates];
        
    return self;
}

- (void)addDPadBackground {
    
    if (dPadBackground == nil) {
        
        dPadBackground = [CALayer layer];
        dPadBackground.name = @"dPadBackgroundForCustomOSC  ";
        dPadBackground.frame = CGRectMake(self.D_PAD_CENTER_X, self.D_PAD_CENTER_Y
                                          , self._leftButton.frame.size.width * 2.5, self._leftButton.frame.size.height * 3);
        dPadBackground.position = CGPointMake(self.D_PAD_CENTER_X, self.D_PAD_CENTER_Y);
        [self.onScreenButtonsArray addObject:dPadBackground];
        
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

- (BOOL)isButtonHoveringOverTrashCan {
    
    CGRect trashCanFrameInViewController = [self._view convertRect:trashCanButton.imageView.frame fromView:trashCanButton.superview];
    
    if (CGRectIntersectsRect(layerCurrentlyBeingTouched.frame, trashCanFrameInViewController)) {
     
        return YES;
    }
    else {
        
        return NO;
    }
}

- (CALayer*)buttonLayerFromName: (NSString*)name {
    
    for (CALayer *buttonLayer in self.onScreenButtonsArray) {
        
        if ([buttonLayer.name isEqualToString:name]) {
            return buttonLayer;
        }
    }
    
    return nil;
}

- (void)layoutOnScreenButtonsAfterUndo {
    
    NSUserDefaults *buttonStatesUserDefaults = [NSUserDefaults standardUserDefaults];
    NSMutableArray *buttonStatesHistoryArray = [[NSMutableArray alloc] init];
    buttonStatesHistoryArray = [buttonStatesUserDefaults objectForKey:@"buttonStatesHistoryArray"];
    
    for (NSData *buttonStateHistoryDataObject in buttonStatesHistoryArray) {
        
        OnScreenButtonState *onScreenButtonState = [NSKeyedUnarchiver unarchivedObjectOfClass:[OnScreenButtonState class] fromData:buttonStateHistoryDataObject error:nil];
        
        for (CALayer *buttonLayer in self.onScreenButtonsArray) {
            
            if ([buttonLayer.name isEqualToString:onScreenButtonState.name]) {
                
                buttonLayer.position = onScreenButtonState.position;
            }
        }
    }
}

- (void)undoButtonTapped {
    
    if ([buttonStatesHistoryArray count] > 0) {
        
        OnScreenButtonState *onScreenButtonState = [buttonStatesHistoryArray lastObject];
        CALayer *buttonLayer = [self buttonLayerFromName:onScreenButtonState.name];
        buttonLayer.position = onScreenButtonState.position;
        buttonLayer.hidden = NO;
        [buttonStatesHistoryArray removeLastObject];
        
        [self saveButtonStateHistory];
    }
}

- (void)saveCurrentButtonPositions {
     
    for (CALayer *buttonLayer in self.onScreenButtonsArray) {
        
        OnScreenButtonState *onScreenButtonState = [[OnScreenButtonState alloc] initWithButtonName:buttonLayer.name  isHidden:buttonLayer.isHidden andPosition:buttonLayer.position];
        [currentButtonStatesArray addObject:onScreenButtonState];
    }
    
    NSMutableArray *currentButtonStatesDataObjectsArray = [[NSMutableArray alloc] init];
    
    for (OnScreenButtonState *buttonState in currentButtonStatesArray) {
        
        NSData *buttonStateDataObject = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [currentButtonStatesDataObjectsArray addObject: buttonStateDataObject];
    }
    
    NSUserDefaults *currentButtonStatesUserDefaults = [NSUserDefaults standardUserDefaults];
    switch (self._level) {
        case OnScreenControlsLevelSimple:
            [currentButtonStatesUserDefaults setObject:currentButtonStatesDataObjectsArray forKey:@"currentButtonStatesDataObjectsArray-Simple"];
            break;
        case OnScreenControlsLevelFull:
            [currentButtonStatesUserDefaults setObject:currentButtonStatesDataObjectsArray forKey:@"currentButtonStatesDataObjectsArray-Full"];
            break;
    }
    [currentButtonStatesUserDefaults synchronize];
}

- (void)saveButtonStateHistory {
    
    NSMutableArray *buttonStatesHistoryDataObjectsArray = [[NSMutableArray alloc] init];
    
    for (OnScreenButtonState *buttonState in buttonStatesHistoryArray) {
        
        NSData *buttonStateHistoryDataObject = [NSKeyedArchiver archivedDataWithRootObject:buttonState requiringSecureCoding:YES error:nil];
        [buttonStatesHistoryDataObjectsArray addObject: buttonStateHistoryDataObject];
    }
    
    NSUserDefaults *buttonStatesHistoryUserDefaults = [NSUserDefaults standardUserDefaults];
    switch (self._level) {
        case OnScreenControlsLevelSimple:
            [buttonStatesHistoryUserDefaults setObject:buttonStatesHistoryDataObjectsArray forKey:@"buttonStateHistoryDataObjectsArray-Simple"];
            break;
        case OnScreenControlsLevelFull:
            [buttonStatesHistoryUserDefaults setObject:buttonStatesHistoryDataObjectsArray forKey:@"buttonStateHistoryDataObjectsArray-Full"];
            break;
    }
    [buttonStatesHistoryUserDefaults synchronize];
}

- (void) populateButtonHistoryStates {
    
    NSMutableArray *buttonStatesHistoryDataObjectsArray = [[NSMutableArray alloc] init];
    
    NSUserDefaults *buttonStatesHistoryUserDefaults = [NSUserDefaults standardUserDefaults];
    switch (self._level) {
        case OnScreenControlsLevelSimple:
            buttonStatesHistoryDataObjectsArray = [buttonStatesHistoryUserDefaults objectForKey:@"buttonStateHistoryDataObjectsArray-Simple"];
            break;
        case OnScreenControlsLevelFull:
            buttonStatesHistoryDataObjectsArray = [buttonStatesHistoryUserDefaults objectForKey:@"buttonStateHistoryDataObjectsArray-Full"];
            break;
    }
    
    for (NSData *buttonStateHistoryDataObject in buttonStatesHistoryDataObjectsArray) {
        
        OnScreenButtonState *onScreenButtonState = [NSKeyedUnarchiver unarchivedObjectOfClass:[OnScreenButtonState class] fromData:buttonStateHistoryDataObject error:nil];
        [buttonStatesHistoryArray addObject:onScreenButtonState];
    }
}

- (void) populateCurrentButtonStates {
    
    NSMutableArray *currentButtonStatesDataObjectsArray = [[NSMutableArray alloc] init];
    
    NSUserDefaults *currentButtonStatesUserDefaults = [NSUserDefaults standardUserDefaults];
    switch (self._level) {
        case OnScreenControlsLevelSimple:
            currentButtonStatesDataObjectsArray = [currentButtonStatesUserDefaults objectForKey:@"currentButtonStatesDataObjectsArray-Simple"];
            break;
        case OnScreenControlsLevelFull:
            currentButtonStatesDataObjectsArray = [currentButtonStatesUserDefaults objectForKey:@"currentButtonStatesDataObjectsArray-Full"];
            break;
    }
    
    for (NSData *currentButtonStateDataObject in currentButtonStatesDataObjectsArray) {
        
        OnScreenButtonState *buttonState = [NSKeyedUnarchiver unarchivedObjectOfClass:[OnScreenButtonState class] fromData:currentButtonStateDataObject error:nil];
        [currentButtonStatesArray addObject:buttonState];
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
        [buttonStatesHistoryArray addObject:onScreenButtonState];
        
        [self saveButtonStateHistory];
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    UITouch *touch = [touches anyObject];
    CGPoint touchLocation = [touch locationInView:_view];
    touchLocation = [[touch view] convertPoint:touchLocation toView:nil];
    
    if ([layerCurrentlyBeingTouched.superlayer.delegate isKindOfClass:[UIButton class]]) { //dont let user move the trashcan, undo, or exit buttons
        return;
    }
    
    layerCurrentlyBeingTouched.position = [touch locationInView:_view]; //move object to touch location
    
    if ([self isButtonHoveringOverTrashCan]) {
     
        trashCanButton.tintColor = [UIColor redColor];
    }
    else {
        
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event {

    layerCurrentlyBeingTouched = nil;
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
    if (layerCurrentlyBeingTouched != nil && [self isButtonHoveringOverTrashCan]) { //check if user wants to throw controller button into the trash can
        
        layerCurrentlyBeingTouched.hidden = YES;
        
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
    
    layerCurrentlyBeingTouched = nil;
}




@end
