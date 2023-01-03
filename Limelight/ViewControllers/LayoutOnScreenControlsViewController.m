//
//  LayoutOnScreenControlsViewController.m
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "LayoutOnScreenControlsViewController.h"
#import "OSCProfilesTableViewController.h"
#import "OnScreenButtonState.h"
#import "OnScreenControls.h"
#import "OSCProfilesManager.h"

@interface LayoutOnScreenControlsViewController ()

@end


@implementation LayoutOnScreenControlsViewController {
    BOOL isToolbarHidden;
    OSCProfilesManager *profilesManager;
}

@synthesize trashCanButton;
@synthesize undoButton;
@synthesize OSCSegmentSelected;
@synthesize toolbarRootView;
@synthesize chevronView;
@synthesize chevronImageView;

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    profilesManager = [OSCProfilesManager sharedManager];

    isToolbarHidden = NO;
        
    //Add curve to bottom of chevron tab view
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.chevronView.bounds byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight) cornerRadii:CGSizeMake(10.0, 10.0)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.view.bounds;
    maskLayer.path  = maskPath.CGPath;
    self.chevronView.layer.mask = maskLayer;
    
    //Add swipe gesture to toolbar to allow user to swipe it up and off screen
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(moveToolbar:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.chevronView addGestureRecognizer:swipeUp];
    [self.chevronImageView addGestureRecognizer:swipeUp];

    //Add tap gesture to toolbar's chevron to allow user to tap it in order to move the toolbar on and off screen
    UITapGestureRecognizer *singleFingerTap =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(moveToolbar:)];
    [self.chevronView addGestureRecognizer:singleFingerTap];
    [self.chevronImageView addGestureRecognizer:singleFingerTap];

    self.layoutOSC = [[LayoutOnScreenControls alloc] initWithView:self.view controllerSup:nil streamConfig:nil oscLevel:OSCSegmentSelected];
    self.layoutOSC._level = 4;
    [self.layoutOSC show];
    
    [self addInnerAnalogSticksToOuterAnalogLayers];

    self.undoButton.alpha = 0.3;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OSCLayoutChanged) name:@"OSCLayoutChanged" object:nil];    //used to notifiy the view controller so that it can either fade in or out its 'Undo button' which will signify to the user whether there are any OSC layout changes to undo
    
    /* This will animate the toolbar with a subtle up and down motion which will telegraph to the user they can hide the toolbar if they wish*/
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{   //adding short time delay to avoid a bug that causes animations running in a modal VC from appearing

        [UIView animateWithDuration:0.3
          delay:0.35
          usingSpringWithDamping:0.8
          initialSpringVelocity:0.5
          options:UIViewAnimationOptionCurveEaseInOut animations:^{ //Animate toolbar up a a very small distance
            //Animations
            self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y - 25, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
            }
          completion:^(BOOL finished) {
            //Completion Block
            [UIView animateWithDuration:0.3
              delay:0
              usingSpringWithDamping:0.7
              initialSpringVelocity:1.0
              options:UIViewAnimationOptionCurveEaseIn animations:^{    //Animate the toolbar back down that same distance
                //Animations
                self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y + 25, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
                }
              completion:^(BOOL finished) {
                //Completion Block
                NSLog (@"done");
            }];
        }];
    });
}


#pragma mark - Helper Functions

/* fades the 'Undo Button' in or out depending on whether the user has any OSC layout changes to undo*/
- (void)OSCLayoutChanged {
    
    if ([self.layoutOSC.layoutChanges count] > 0) {
        
        self.undoButton.alpha = 1.0;
    }
    else {
        
        self.undoButton.alpha = 0.3;
    }
}

/* animates the toolbar up and off the screen or back down onto the screen*/
- (void)moveToolbar:(UISwipeGestureRecognizer *)sender {
    
    if (isToolbarHidden == NO) {
        
        [UIView animateWithDuration:0.2 animations:^{   //animates toolbar up and off screen
            //Animations
            self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y - self.toolbarRootView.frame.size.height, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
        }
                         completion:^(BOOL finished) {
            if (finished) {
                
                self->isToolbarHidden = YES;
                self.chevronImageView.image = [UIImage imageNamed:@"chevron.compact.down"];
            }
        }];
    }
    else {
        
        [UIView animateWithDuration:0.2 animations:^{   //animates the toolbar back down into view
            //Animations
            self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y + self.toolbarRootView.frame.size.height, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
        }
                         completion:^(BOOL finished) {
            if (finished) {
                
                self->isToolbarHidden = NO;
                self.chevronImageView.image = [UIImage imageNamed:@"chevron.compact.up"];
            }
        }];
    }
}

- (void)addInnerAnalogSticksToOuterAnalogLayers {
    
    [self.layoutOSC._rightStickBackground addSublayer: self.layoutOSC._rightStick];
    self.layoutOSC._rightStick.position = CGPointMake(self.layoutOSC._rightStickBackground.frame.size.width / 2, self.layoutOSC._rightStickBackground.frame.size.height / 2);
    
    [self.layoutOSC._leftStickBackground addSublayer: self.layoutOSC._leftStick];
    self.layoutOSC._leftStick.position = CGPointMake(self.layoutOSC._leftStickBackground.frame.size.width / 2, self.layoutOSC._leftStickBackground.frame.size.height / 2);
}


#pragma mark - UIButton Actions

- (IBAction)closeTapped:(id)sender {
        
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)trashCanTapped:(id)sender {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Buttons Here" message:@"Drag and drop buttons onto this trash can to remove them from the interface" preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)undoTapped:(id)sender {
    
    if ([self.layoutOSC.layoutChanges count] > 0) { //check if there are layout changes to roll back to
        
        //Get the name, position, and visiblity state of the button the user last moved
        OnScreenButtonState *onScreenButtonState = [self.layoutOSC.layoutChanges lastObject];
        CALayer *buttonLayer = [self.layoutOSC buttonLayerFromName:onScreenButtonState.name];
        
        //Set the button's position and visiblity to what it was before the user last moved it
        buttonLayer.position = onScreenButtonState.position;
        buttonLayer.hidden = onScreenButtonState.isHidden;
        
        [self.layoutOSC.layoutChanges removeLastObject];
        
        [self OSCLayoutChanged];    //will fade the undo button in or depending on whether there are any further changes to undo
    }
    else {
        
        UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@"Nothing to Undo"] message: @"You haven't made any changes to undo" preferredStyle:UIAlertControllerStyleAlert];
        [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [savedAlertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [self presentViewController:savedAlertController animated:YES completion:nil];
    }
}

/*show pop up notification that lets users choose to save the current OSC layout configuration as a profile they can load when they want. User can also choose to cancel out of this pop up*/
- (IBAction)saveTapped:(id)sender {
                
    UIAlertController * inputNameAlertController = [UIAlertController alertControllerWithTitle: @"Enter the name you want to save this controller profile as" message: @"" preferredStyle:UIAlertControllerStyleAlert];
    [inputNameAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {  //pop up notification with text field where user can enter the text they wish to name their OSC layout profile
        
        textField.placeholder = @"name";
        textField.textColor = [UIColor lightGrayColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleNone;
    }];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {   //add save button to pop up notification
        
        NSArray * textFields = inputNameAlertController.textFields;
        UITextField * nameField = textFields[0];
        NSString *enteredProfileName = nameField.text;
        
        if ([enteredProfileName isEqualToString:@"Default"]) {  //don't user user overwrite the 'Default' profile
         
            UIAlertController * alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Saving over the 'Default' profile is not allowed"] preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                
                [alertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
            }]];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
        else if ([enteredProfileName length] == 0) {    //if user entered no text but tapped the 'Save' button let them know they can't do that
            
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Profile name cannot be blank!"] preferredStyle:UIAlertControllerStyleAlert];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { //show pop up notification letting user know they must enter a name in the text field if they wish to save the controller profile
                
                [savedAlertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
            }]];
            
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else if ([profilesManager profileNameAlreadyExist:enteredProfileName] == YES) {  //if entered profile name already exists then let the user know. Offer to allow them to overwrite the existing profile
            
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Another profile with the name '%@' already exists! Do you want to overwrite it?", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {    //overwrite existing profile
                [self->profilesManager saveOSCProfileWithName: enteredProfileName andButtonLayersArray:self.layoutOSC.OSCButtonLayers];
            }]];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { //don't overwrite the existing profile
                [savedAlertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else {  //if user entered a valid name that doesn't already exist then save it to persistent storage
            
            [self->profilesManager saveOSCProfileWithName: enteredProfileName andButtonLayersArray:self.layoutOSC.OSCButtonLayers];
            [self->profilesManager setOSCProfileAsSelectedWithName: enteredProfileName];
            
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"%@ profile saved and set as your active in-game controller profile layout", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { //Let user know this profile is now the selected controller layout

                [savedAlertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
    }]];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { //adds a button that allows user to decline the option to save the controller layout they currently see on screen 
        
        [inputNameAlertController dismissViewControllerAnimated:NO completion:nil];
    }]];
    
    [self presentViewController:inputNameAlertController animated:YES completion:nil];
}

/* Shows the VC that lists all OSC profiles the user can choose from*/
- (IBAction)loadTapped:(id)sender {
    
    UIStoryboard *storyboard;
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    if (isIPhone) {
        storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
    }
    else {
        storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
    }
    
    OSCProfilesTableViewController *vc = [storyboard   instantiateViewControllerWithIdentifier:@"OSCProfilesTableViewController"] ;
    
    vc.didDismiss = ^() {   //block that will be called when the profiles list VC is dismissed. code will move all buttons to where they need to go depending on which profile the user selected
        
        [self.layoutOSC updateControls];  //creates and saves a 'Default' OSC profile or loads the one the user selected on the previous screen
        
        [self addInnerAnalogSticksToOuterAnalogLayers];
        
        [self.layoutOSC.layoutChanges removeAllObjects];  //since a new OSC profile is being loaded, this will remove all layout changes made from the array
        
        [self OSCLayoutChanged];    //fades the 'Undo Button' out
    };
    
    [self presentViewController:vc animated:YES completion:nil];
}


#pragma mark - Touch Methods

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
 
    for (UITouch* touch in touches) {
        
        CGPoint touchLocation = [touch locationInView:self.view];
        touchLocation = [[touch view] convertPoint:touchLocation toView:nil];
        CALayer *layer = [self.view.layer hitTest:touchLocation];
        
        if (layer == self.toolbarRootView.layer ||
            layer == self.chevronView.layer ||
            layer == self.chevronImageView.layer ||
            layer == self.toolbarStackView.layer) {  //don't let user move toolbar and toolbar related stuff
            
            return;
        }
    }
    
    [self.layoutOSC touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [self.layoutOSC touchesMoved:touches withEvent:event];
    
    if ([self.layoutOSC isLayer:self.layoutOSC.layerCurrentlyBeingTouched hoveringOverButton:trashCanButton]) { //check if the layer the user is currently moving is hovering over the trash can button
     
        trashCanButton.tintColor = [UIColor redColor];
    }
    else {
        
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if (self.layoutOSC.layerCurrentlyBeingTouched != nil &&
        [self.layoutOSC isLayer:self.layoutOSC.layerCurrentlyBeingTouched hoveringOverButton:trashCanButton]) { //check if user wants to throw controller button into the trash can
        
        self.layoutOSC.layerCurrentlyBeingTouched.hidden = YES;
        
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
    
    [self.layoutOSC touchesEnded:touches withEvent:event];
}

@end
