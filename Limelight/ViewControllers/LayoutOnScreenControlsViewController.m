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
    [self addAnalogSticksToBackground];
    
    if ([layoutOnScreenControls.buttonStatesHistoryArray count] == 0) {
        self.undoButton.alpha = 0.3;
    }
    else {
        self.undoButton.alpha = 1.0;
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buttonsHistoryChanged:) name:@"ButtonsHistoryChanged" object:nil];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{   //keeps VC modal animation from completing the toolbar's bounce animation immediately

        [UIView animateWithDuration:0.3
          delay:1
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

- (void)buttonsHistoryChanged:(NSNotification *)notification {
    
    if ([layoutOnScreenControls.buttonStatesHistoryArray count] > 0) {
        
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

- (void)addAnalogSticksToBackground {
    
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
    
    if ([layoutOnScreenControls.buttonStatesHistoryArray count] > 0) {
        
        OnScreenButtonState *onScreenButtonState = [layoutOnScreenControls.buttonStatesHistoryArray lastObject];
        CALayer *buttonLayer = [layoutOnScreenControls buttonLayerFromName:onScreenButtonState.name];
        buttonLayer.position = onScreenButtonState.position;
        buttonLayer.hidden = NO;
        [layoutOnScreenControls.buttonStatesHistoryArray removeLastObject];
        
        [layoutOnScreenControls saveButtonStateHistory];
    }
    else {
        
        UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@"Nothing to Undo"] message: @"You haven't made any changes to undo" preferredStyle:UIAlertControllerStyleAlert];
        [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [savedAlertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [self presentViewController:savedAlertController animated:YES completion:nil];
    }
}

- (IBAction)saveTapped:(id)sender {
    
    __block NSString *enteredProfileName = @"";
            
    //pop up notification that lets users name profile and either cancel or save
    UIAlertController * inputNameAlertController = [UIAlertController alertControllerWithTitle: @"Name Profile"
                                                                              message: @"Enter the name you want to save this controller profile as"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    [inputNameAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"name";
        textField.textColor = [UIColor blueColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleNone;
    }];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray * textFields = inputNameAlertController.textFields;
        UITextField * nameField = textFields[0];
        enteredProfileName = nameField.text;
        
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfileNamesArray"] containsObject:enteredProfileName]) {
            
            //let user know another profile with the same name already exists
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Another profile with the name '%@' already exists! Do you want to overwrite it?", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [self->layoutOnScreenControls saveOSCProfileWithName: enteredProfileName];
                [self->layoutOnScreenControls saveOSCPositionsWithKeyName: enteredProfileName];
                [[NSUserDefaults standardUserDefaults] setObject:enteredProfileName forKey:@"SelectedOSCProfile"];
            }]];
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"No" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [savedAlertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else if ([enteredProfileName length] == 0) {
            
            //let user know not to leave name blank
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Profile name cannot be blank!"] preferredStyle:UIAlertControllerStyleAlert];
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [savedAlertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
            }]];
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
        else {
            
            [self->layoutOnScreenControls saveOSCProfileWithName: enteredProfileName];
            [self->layoutOnScreenControls saveOSCPositionsWithKeyName: enteredProfileName];
            [[NSUserDefaults standardUserDefaults] setObject:enteredProfileName forKey:@"SelectedOSCProfile"];
            
            //Let user know this profile is now the selected controller layout
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"%@ profile saved and set as your active in-game controller profile layout", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                
                [savedAlertController dismissViewControllerAnimated:NO completion:nil];
            }]];
            [self presentViewController:savedAlertController animated:YES completion:nil];
        }
    }]];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
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
        NSLog(@"Dismissed SecondViewController");
        [self->layoutOnScreenControls layoutOSC];
        [self->layoutOnScreenControls loadButtonHistory];
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
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    [layoutOnScreenControls touchesEnded:touches withEvent:event];
}

@end
