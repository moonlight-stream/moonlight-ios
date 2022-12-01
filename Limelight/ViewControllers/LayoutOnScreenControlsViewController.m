//
//  LayoutOnScreenControlsViewController.m
//  Moonlight
//
//  Created by Long Le on 9/27/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "LayoutOnScreenControlsViewController.h"

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
    //pop up notification that lets users name profile and either cancel or save
    UIAlertController * alertController = [UIAlertController alertControllerWithTitle: @"Name Profile"
                                                                                      message: @"Input controller profile name"
                                                                                  preferredStyle:UIAlertControllerStyleAlert];
        [alertController addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"name";
            textField.textColor = [UIColor blueColor];
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            textField.borderStyle = UITextBorderStyleRoundedRect;
        }];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [alertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [alertController addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            NSArray * textfields = alertController.textFields;
            UITextField * namefield = textfields[0];
            NSLog(@"%@",namefield.text);
            
            //Save OSCProfile
            [self->layoutOnScreenControls saveOSCProfileToArrayWithName: namefield.text];
            
            //Let user know this profile is now the selected controller layout
            UIAlertController * savedAlertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: [NSString stringWithFormat:@"%@ profile saved and set as your active in-game controller profile layout", namefield.text] preferredStyle:UIAlertControllerStyleAlert];
                [savedAlertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                    
                    //check if the user entered a profile name that already exists
                    
                    [savedAlertController dismissViewControllerAnimated:NO completion:nil];
                    
                    
                }]];
            [self presentViewController:savedAlertController animated:YES completion:nil];

        }]];
        [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)loadTapped:(id)sender {
    //load TVC that shows all controller profiles by name
    
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
