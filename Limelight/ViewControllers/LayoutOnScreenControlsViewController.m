//
//  LayoutOnScreenControlsViewController.m
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "LayoutOnScreenControlsViewController.h"
#import "OSCProfilesTableViewController.h"

@interface LayoutOnScreenControlsViewController ()

@end

@implementation LayoutOnScreenControlsViewController {
    
    LayoutOnScreenControls *layoutOnScreenControls;
}

@synthesize onScreenControlSegmentSelected;

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    layoutOnScreenControls = [[LayoutOnScreenControls alloc] initWithView:self.view controllerSup:nil streamConfig:nil oscLevel:onScreenControlSegmentSelected];
    [layoutOnScreenControls show];
    [self addAnalogSticksToBackground];
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

- (IBAction)saveTapped:(id)sender {
    
    __block NSString *enteredProfileName = @"";
            
    //pop up notification that lets users name profile and either cancel or save
    UIAlertController * inputNameAlertController = [UIAlertController alertControllerWithTitle: @"Name Profile"
                                                                              message: @"Input controller profile name"
                                                                       preferredStyle:UIAlertControllerStyleAlert];
    [inputNameAlertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        textField.placeholder = @"name";
        textField.textColor = [UIColor blueColor];
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.borderStyle = UITextBorderStyleRoundedRect;
    }];
    [inputNameAlertController addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSArray * textFields = inputNameAlertController.textFields;
        UITextField * nameField = textFields[0];
        enteredProfileName = nameField.text;
        
        if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfileNamesArray"] containsObject:enteredProfileName]) {
            
            //let user know another profile with the same name already exists
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"Another profile with the name '%@' already exists!", enteredProfileName] preferredStyle:UIAlertControllerStyleAlert];
            [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                [savedAlertController dismissViewControllerAnimated:NO completion:^{
                    [self presentViewController:inputNameAlertController animated:YES completion:nil];
                }];
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
            
            [self->layoutOnScreenControls saveOSCProfileToArrayWithName: enteredProfileName];
            [self->layoutOnScreenControls saveOSCPositionsToStorageWithKeyName: enteredProfileName];
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
    //load TVC that shows all controller profiles by name
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"iPhone" bundle:nil];
    OSCProfilesTableViewController *vc = [storyboard   instantiateViewControllerWithIdentifier:@"OSCProfilesTableViewController"] ;
    
    vc.didDismiss = ^() {
        NSLog(@"Dismissed SecondViewController");
        [self->layoutOnScreenControls layoutOSC];
    };
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
 
    [layoutOnScreenControls touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    
    [layoutOnScreenControls touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    
    [layoutOnScreenControls touchesEnded:touches withEvent:event];
}

@end
