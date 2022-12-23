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
@synthesize OSCProfiles;

- (void)viewDidLoad {
    
    [super viewDidLoad];
        
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // Register the nib file with the table view
    [self.tableView registerNib:[UINib nibWithNibName:@"ProfileTableViewCell" bundle:nil] forCellReuseIdentifier:@"Cell"];
    
    self.OSCProfiles = [[NSMutableArray alloc] init];
        
    [self.OSCProfiles addObjectsFromArray: [[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfiles"]];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear: animated];
    
    if ([self.OSCProfiles count] > 0) { //scroll to selected profile if user has any saved profiles
        
        LayoutOnScreenControlsViewController *presentingVC = (LayoutOnScreenControlsViewController*)self.presentingViewController;
        OSCProfile *selectedOSCProfile = [presentingVC.layoutOSC selectedOSCProfile];
        NSUInteger index = [self.OSCProfiles indexOfObject:selectedOSCProfile];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

#pragma mark - UIButton Actions

- (IBAction)loadTapped:(id)sender {
    
    if ([self.OSCProfiles count] > 0) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *selectedOSCProfile = [self.OSCProfiles objectAtIndex:selectedIndexPath.row];
        [userDefaults setObject:selectedOSCProfile forKey:@"SelectedOSCProfileName"];
        [userDefaults synchronize];
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];

    if (self.didDismiss) {
        self.didDismiss();
    }
}

- (IBAction)cancelTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if ([self.OSCProfiles count] == 0) {    //if user deleted all profiles this will create another 'Default' profile with Moonlight's legacy 'Full' OSC layout
        
        if (self.didDismiss) {
            self.didDismiss();
        }
    }
}


#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.OSCProfiles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.name.text = self.OSCProfiles[indexPath.row];
    
    if ([self.OSCProfiles[indexPath.row] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfileName"]]) { //if this cell contains the name of the currently selected OSC profile then add a checkmark to the right side of the cell
        
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
    
    if ([self.OSCProfiles[indexPath.row] isEqualToString:@"Default"]) {   //If user is attempting to delete the 'Default' profile then show a pop up telling user they can't do that
        
        UIAlertController * alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: @"Deleting the 'Default' profile is not allowed" preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [alertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        
        [self presentViewController:alertController animated:YES completion:nil];
        
        return;
    }
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {

        OSCProfile *profile = [self.OSCProfiles objectAtIndex:indexPath.row];
        
        if (profile.isSelected) {   //if user is deleting the currently selected OSC profile then make the  profile at its previous index the currently selected OSC profile
            
            if (indexPath.row > 0) {    //user shouldn't be able to delete the cell at row 0 because that row contains the 'Default' profile which we check for above, but just in case they're able to add this to avoid an app crash
                
                OSCProfile *profile = [self.OSCProfiles objectAtIndex:indexPath.row - 1];
                profile.isSelected = YES;
            }
        }
        
        [self.OSCProfiles removeObjectAtIndex:indexPath.row];
        
        [[NSUserDefaults standardUserDefaults] setObject:self.OSCProfiles forKey:@"OSCProfiles"];

        [[NSUserDefaults standardUserDefaults] synchronize];
        
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
    
        [[NSUserDefaults standardUserDefaults] setObject:self.OSCProfiles[selectedIndexPath.row] forKey:@"SelectedOSCProfileName"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
