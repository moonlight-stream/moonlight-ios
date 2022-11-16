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
    
    layoutOnScreenControls = [[LayoutOnScreenControls alloc] initWithView:self.view controllerSup:nil streamConfig:nil];
    [layoutOnScreenControls setLevel: onScreenControlSegmentSelected];
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
    
    [layoutOnScreenControls saveCurrentButtonPositions];
    
    [self dismissViewControllerAnimated:YES completion:nil];
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
