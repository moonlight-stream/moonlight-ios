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

@interface LayoutOnScreenControlsViewController ()

@end


@implementation LayoutOnScreenControlsViewController {
    
    LayoutOnScreenControls *layoutOnScreenControls;
    BOOL isToolbarHidden;
}

@synthesize trashCanButton;
@synthesize undoButton;
@synthesize onScreenControlSegmentSelected;
@synthesize toolbarRootView;
@synthesize chevronView;
@synthesize chevronImageView;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    isToolbarHidden = NO;
        
    //Add curve to bottom of chevron tab view
    UIBezierPath *maskPath = [UIBezierPath bezierPathWithRoundedRect:self.chevronView.bounds byRoundingCorners:(UIRectCornerBottomLeft | UIRectCornerBottomRight) cornerRadii:CGSizeMake(10.0, 10.0)];
    CAShapeLayer *maskLayer = [[CAShapeLayer alloc] init];
    maskLayer.frame = self.view.bounds;
    maskLayer.path  = maskPath.CGPath;
    self.chevronView.layer.mask = maskLayer;
    
    
    UISwipeGestureRecognizer *swipeUp = [[UISwipeGestureRecognizer alloc]initWithTarget:self action:@selector(moveToolbar:)];
    swipeUp.direction = UISwipeGestureRecognizerDirectionUp;
    [self.chevronView addGestureRecognizer:swipeUp];
    [self.chevronImageView addGestureRecognizer:swipeUp];

    UITapGestureRecognizer *singleFingerTap =
      [[UITapGestureRecognizer alloc] initWithTarget:self
                                              action:@selector(moveToolbar:)];
    [self.chevronView addGestureRecognizer:singleFingerTap];
    [self.chevronImageView addGestureRecognizer:singleFingerTap];

    layoutOnScreenControls = [[LayoutOnScreenControls alloc] initWithView:self.view controllerSup:nil streamConfig:nil oscLevel:onScreenControlSegmentSelected];
    layoutOnScreenControls._level = 4;
    [layoutOnScreenControls show];
    [self addInnerAnalogSticksToOuterAnalogLayers];

    self.undoButton.alpha = 0.3;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(OSCLayoutHistoryChanged:) name:@"OSCLayoutHistoryChanged" object:nil];    //used to notifiy the view controller so that it can either fade out or fade in its 'Undo button' which will signify to the user whether there are any OSC layout changes to undo
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{   //keeps VC modal animation from completing the toolbar's bounce animation immediately

        [UIView animateWithDuration:0.3
          delay:0.35
          usingSpringWithDamping:0.8
          initialSpringVelocity:0.5
          options:UIViewAnimationOptionCurveEaseInOut animations:^{
            //Animations
            self.toolbarRootView.frame = CGRectMake(self.toolbarRootView.frame.origin.x, self.toolbarRootView.frame.origin.y - 25, self.toolbarRootView.frame.size.width, self.toolbarRootView.frame.size.height);
            }
          completion:^(BOOL finished) {
            //Completion Block
            [UIView animateWithDuration:0.3
              delay:0
              usingSpringWithDamping:0.7
              initialSpringVelocity:1.0
              options:UIViewAnimationOptionCurveEaseIn animations:^{
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

- (void)OSCLayoutHistoryChanged:(NSNotification *)notification {
    
    if ([layoutOnScreenControls.buttonStateHistory count] > 0) {
        
        self.undoButton.alpha = 1.0;
    }
    else {
        
        self.undoButton.alpha = 0.3;
    }
}

- (void)moveToolbar:(UISwipeGestureRecognizer *)sender {
    
    if (isToolbarHidden == NO) {
        
        [UIView animateWithDuration:0.2 animations:^{
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
        
        [UIView animateWithDuration:0.2 animations:^{
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
    
    [layoutOnScreenControls._rightStickBackground addSublayer: layoutOnScreenControls._rightStick];
    layoutOnScreenControls._rightStick.position = CGPointMake(layoutOnScreenControls._rightStickBackground.frame.size.width / 2, layoutOnScreenControls._rightStickBackground.frame.size.height / 2);
    
    [layoutOnScreenControls._leftStickBackground addSublayer: layoutOnScreenControls._leftStick];
    layoutOnScreenControls._leftStick.position = CGPointMake(layoutOnScreenControls._leftStickBackground.frame.size.width / 2, layoutOnScreenControls._leftStickBackground.frame.size.height / 2);
}

- (IBAction)trashCanTapped:(id)sender {
    
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Delete Buttons Here" message:@"Drag and drop buttons onto this trash can to remove them from the interface" preferredStyle:UIAlertControllerStyleAlert];

    UIAlertAction *ok = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                            //button click event
                        }];
    [alert addAction:ok];
    [self presentViewController:alert animated:YES completion:nil];
}

- (IBAction)closeTapped:(id)sender {
        
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)undoTapped:(id)sender {
    
    if ([layoutOnScreenControls.buttonStateHistory count] > 0) {
        
        OnScreenButtonState *onScreenButtonState = [layoutOnScreenControls.buttonStateHistory lastObject];
        CALayer *buttonLayer = [layoutOnScreenControls buttonLayerFromName:onScreenButtonState.name];
        buttonLayer.position = onScreenButtonState.position;
        buttonLayer.hidden = onScreenButtonState.isHidden;
        
        [layoutOnScreenControls.buttonStateHistory removeLastObject];
        
        [self OSCLayoutHistoryChanged: nil];    //will fade the undo button in or depending on whether there are any further changes to undo
    }
    else {
        
        UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@"Nothing to Undo"] message: @"You haven't made any changes to undo" preferredStyle:UIAlertControllerStyleAlert];
        [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [savedAlertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [self presentViewController:savedAlertController animated:YES completion:nil];
    }
}

/*show pop up notification that lets users choose to either name profile. User can also choose to cancel out of this pop up or Save the name they've entered*/
- (IBAction)saveTapped:(id)sender {
    
    __block NSString *enteredProfileName = @"";
            
    UIAlertController * inputNameAlertController = [UIAlertController alertControllerWithTitle: @"Enter the name you want to save this controller profile as" message: @"" preferredStyle:UIAlertControllerStyleAlert];
    [inputNameAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {  //pop up notification with text field where user can enter the text they wish to name their on screen controller layout profile
        
        textField.placeholder = @"name";
        textField.textColor = [UIColor blueColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleNone;
    }];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {   //add save button to pop up notification
        
        NSArray * textFields = inputNameAlertController.textFields;
        UITextField * nameField = textFields[0];
        enteredProfileName = nameField.text;
        
        if ([enteredProfileName isEqualToString:@"Default"]) {  //don't user user overwrite the 'Default' profile
         
            UIAlertController * alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Saving over the 'Default' profile is not allowed"] preferredStyle:UIAlertControllerStyleAlert];
            
            [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { //show pop up notification letting user know they must enter a name in the text field if they wish to save the controller profile
                
                [alertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
            }]];
            
            [self presentViewController:alertController animated:YES completion:nil];
        }
        else if ([enteredProfileName length] == 0) {    //if user entered no text but tapped the 'Save' button
            
            //let user know not to leave name blank
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Profile name cannot be blank!"] preferredStyle:UIAlertControllerStyleAlert];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { //show pop up notification letting user know they must enter a name in the text field if they wish to save the controller profile
                
                [savedAlertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
            }]];
            
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfileNames"] containsObject:enteredProfileName]) {  //if entered profile name already exists then let the user know. Offer to allow them to overwrite the existing profile
            
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Another profile with the name '%@' already exists! Do you want to overwrite it?", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {    //overwrite existing profile
                [self->layoutOnScreenControls saveOSCProfileWithName: enteredProfileName];
                [self->layoutOnScreenControls saveOSCPositionsWithKeyName: enteredProfileName];
                [[NSUserDefaults standardUserDefaults] setObject:enteredProfileName forKey:@"SelectedOSCProfile"];
            }]];
            
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) { //don't overwrite the existing profile
                [savedAlertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else {  //if user entered a valid name that doesn't already exist then save it to persistent storage
            
            [self->layoutOnScreenControls saveOSCProfileWithName: enteredProfileName];
            [self->layoutOnScreenControls saveOSCPositionsWithKeyName: enteredProfileName];
            [[NSUserDefaults standardUserDefaults] setObject:enteredProfileName forKey:@"SelectedOSCProfile"];
            
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

- (IBAction)loadTapped:(id)sender {
    
    UIStoryboard *storyboard;
    BOOL isIPhone = ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPhone);
    if (isIPhone) {
        //load TVC that shows all controller profiles by name
        storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
    }
    else {
        storyboard = [UIStoryboard storyboardWithName:@"iPad" bundle:nil];
    }
    OSCProfilesTableViewController *vc = [storyboard   instantiateViewControllerWithIdentifier:@"OSCProfilesTableViewController"] ;
    vc.didDismiss = ^() {
        
        [self->layoutOnScreenControls updateControls];
        [self addInnerAnalogSticksToOuterAnalogLayers];
        
        [self->layoutOnScreenControls.buttonStateHistory removeAllObjects];
        [self OSCLayoutHistoryChanged:nil];
    };
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
 
    for (UITouch* touch in touches) {
        
        CGPoint touchLocation = [touch locationInView:self.view];
        touchLocation = [[touch view] convertPoint:touchLocation toView:nil];
        CALayer *layer = [self.view.layer hitTest:touchLocation];
        
        if (layer == self.toolbarRootView.layer || layer == self.chevronView.layer || layer == self.chevronImageView.layer || layer == self.toolbarStackView.layer) {  //don't let user move Tool Bar stuff
            return;
        }
    }
    
    [layoutOnScreenControls touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [layoutOnScreenControls touchesMoved:touches withEvent:event];
    
    if ([layoutOnScreenControls isLayer:layoutOnScreenControls.layerCurrentlyBeingTouched hoveringOverButton:trashCanButton]) {
     
        trashCanButton.tintColor = [UIColor redColor];
    }
    else {
        
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    if (layoutOnScreenControls.layerCurrentlyBeingTouched != nil && [layoutOnScreenControls isLayer:layoutOnScreenControls.layerCurrentlyBeingTouched hoveringOverButton:trashCanButton]) { //check if user wants to throw controller button into the trash can
        
        layoutOnScreenControls.layerCurrentlyBeingTouched.hidden = YES;
        
        trashCanButton.tintColor = [UIColor colorWithRed:171.0/255.0 green:157.0/255.0 blue:255.0/255.0 alpha:1];
    }
    
    [layoutOnScreenControls touchesEnded:touches withEvent:event];
}

@end
