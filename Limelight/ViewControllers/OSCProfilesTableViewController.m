//
//  OSCProfilesTableViewController.m
//  Moonlight
//
//  Created by Long Le on 11/28/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "OSCProfilesTableViewController.h"
#import "LayoutOnScreenControlsViewController.h"
#import "ProfileTableViewCell.h"

const double NAV_BAR_HEIGHT = 50;

@interface OSCProfilesTableViewController ()

@end

@implementation OSCProfilesTableViewController {
    
    NSIndexPath *selectedIndexPath;
}

@synthesize tableView;
@synthesize OSCProfileNames;

- (void)viewDidLoad {
    
    [super viewDidLoad];
        
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // Register the nib file with the table view
    [self.tableView registerNib:[UINib nibWithNibName:@"ProfileTableViewCell" bundle:nil] forCellReuseIdentifier:@"Cell"];
    
    self.OSCProfileNames = [[NSMutableArray alloc] init];
        
    [self.OSCProfileNames addObjectsFromArray: [[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfileNames"]];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear: animated];
    
    if ([self.OSCProfileNames count] > 0) { //scroll to selected profile if user has any saved profiles
        
        NSInteger profileIndexPosition = [self indexPositionForSelectedOSCProfile: [[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"]];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:profileIndexPosition inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

#pragma mark - Helper Functions

- (NSInteger)indexPositionForSelectedOSCProfile: (NSString*)name {

    for (int i = 0; i < [self.OSCProfileNames count]; i++) {
        
        if ([name isEqualToString:self.OSCProfileNames[i]]) {
            
            return i;
        }
    }
    
    return 0;
}

#pragma mark - UIButton Actions

- (IBAction)loadTapped:(id)sender {
    
    if ([self.OSCProfileNames count] > 0) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *selectedOSCProfile = [self.OSCProfileNames objectAtIndex:selectedIndexPath.row];
        [userDefaults setObject:selectedOSCProfile forKey:@"SelectedOSCProfile"];
        [userDefaults synchronize];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];

    if (self.didDismiss) {
        self.didDismiss();
    }
}

- (IBAction)cancelTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if ([self.OSCProfileNames count] == 0) {    //if user deleted all profiles this will create another 'Default' profile with Moonlight's legacy 'Full' OSC layout
        
        if (self.didDismiss) {
            self.didDismiss();
        }
    }
}


#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.OSCProfileNames count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.name.text = self.OSCProfileNames[indexPath.row];
    
    if ([self.OSCProfileNames[indexPath.row] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"]]) { //if this cell contains the name of the currently selected OSC profile then add a checkmark to the right side of the cell
        
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        selectedIndexPath = indexPath;  //keeps track of which cell contains the currently selected OSC profile
    }
    else {
        
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if ([self.OSCProfileNames[indexPath.row] isEqualToString:@"Default"]) {   //If user is attempting to delete the 'Default' profile then show pop up telling user they can't delete the default profile
        
        UIAlertController * alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: @"Deleting the 'Default' profile is not allowed" preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [alertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        
        [self presentViewController:alertController animated:YES completion:nil];
        
        return;
    }
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *profile = [self.OSCProfileNames objectAtIndex:indexPath.row];
        
        [userDefaults removeObjectForKey:[NSString stringWithFormat:@"%@-ButtonsLayout", profile]]; //Delete profile's corresponding array of 'OnScreenButtonState' objects from persistant storage
        
        //Delete profile name from persistant storage
        [self.OSCProfileNames removeObjectAtIndex:indexPath.row];
        [userDefaults setObject:self.OSCProfileNames forKey:@"OSCProfileNames"];
        
        if (indexPath.row == selectedIndexPath.row) {   //if user is deleting the currently selected OSC profile then make the previous profile the currently selected OSC profile
            
            if (indexPath.row > 0) {
                
                [userDefaults setObject:[self.OSCProfileNames objectAtIndex:indexPath.row - 1] forKey:@"SelectedOSCProfile"];
            }
        }

        [userDefaults synchronize];
        
        [tableView reloadData]; 
    }
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger newRow = [indexPath row];
    NSInteger oldRow = [selectedIndexPath row];

    if (newRow != oldRow)
    {
        UITableViewCell *newCell = [tableView cellForRowAtIndexPath: indexPath];
        newCell.accessoryType = UITableViewCellAccessoryCheckmark;

        UITableViewCell *oldCell = [tableView cellForRowAtIndexPath: selectedIndexPath];
        oldCell.accessoryType = UITableViewCellAccessoryNone;

        selectedIndexPath = indexPath;
    
        [[NSUserDefaults standardUserDefaults] setObject:self.OSCProfileNames[selectedIndexPath.row] forKey:@"SelectedOSCProfile"];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
