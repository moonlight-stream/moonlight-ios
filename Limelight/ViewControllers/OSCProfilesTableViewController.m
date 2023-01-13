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
#import "OSCProfile.h"
#import "OnScreenButtonState.h"
#import "OSCProfilesManager.h"

const double NAV_BAR_HEIGHT = 50;

@interface OSCProfilesTableViewController ()

@end

@implementation OSCProfilesTableViewController {
    OSCProfilesManager *profilesManager;
}

@synthesize tableView;

- (void)viewDidLoad {
    [super viewDidLoad];
        
    profilesManager = [OSCProfilesManager sharedManager];

    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // Register the custom cell nib file with the table view
    [self.tableView registerNib:[UINib nibWithNibName:@"ProfileTableViewCell" bundle:nil] forCellReuseIdentifier:@"Cell"];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    
    if ([[profilesManager getAllProfiles] count] > 0) { // scroll to selected profile if user has any saved profiles
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[profilesManager getIndexOfSelectedProfile] inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

#pragma mark - UIButton Actions

/* Loads the OSC profile that user selected, dismisses this view, then tells the presenting view controller to lay out the on screen buttons according to the selected profile's instructions */
- (IBAction)loadTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];

    if (self.didDismissOSCProfilesTVC) {    // tells the presenting view controller to lay out the on screen buttons according to the selected profile's instructions
        self.didDismissOSCProfilesTVC();
    }
}

- (IBAction)cancelTapped:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[profilesManager getAllProfiles] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    OSCProfile *profile = [[profilesManager getAllProfiles] objectAtIndex: indexPath.row];
    cell.name.text = profile.name;
    
    if ([profile.name isEqualToString: [profilesManager getSelectedProfile].name]) { // if this cell contains the name of the currently selected OSC profile then add a checkmark to the right side of the cell
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
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
    NSMutableArray *profiles = [profilesManager getAllProfiles];    // create new instance of array containing all profiles from persistent storage so that we can modify this array before we save it back to persistent storage

    if ([[[profiles objectAtIndex:indexPath.row] name] isEqualToString:@"Default"]) {   // if user is attempting to delete the 'Default' profile then show a pop up telling user they can't do that and return out of this method
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: @"Deleting the 'Default' profile is not allowed" preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [alertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        [self presentViewController:alertController animated:YES completion:nil];
        
        return;
    }
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        OSCProfile *profile = [profiles objectAtIndex:indexPath.row];
        if (profile.isSelected) {   // if user is deleting the currently selected OSC profile then make the  profile at its previous index the currently selected profile
            if (indexPath.row > 0) {    // check that row is greater than zero to avoid an out of bounds crash. should not be possible right now since the 'Default' profile is always at row 0 and they're not allowed to delete it
                OSCProfile *profile = [profiles objectAtIndex:indexPath.row - 1];
                profile.isSelected = YES;
            }
        }
        
        [profiles removeObjectAtIndex:indexPath.row];
        
        /* save OSC profiles array to persistent storage */
        NSMutableArray *profilesEncoded = [[NSMutableArray alloc] init];
        for (OSCProfile *profileDecoded in profiles) {  // encode each OSC profile object and add them to an array
            
            NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
            [profilesEncoded addObject:profileEncoded];
        }
        
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded
                                             requiringSecureCoding:YES error:nil];  // encode the array itself, NOT the objects in the array
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [tableView reloadData]; 
    }
}

#pragma mark - TableView Delegate

/* When user taps a cell it moves the checkmark to that cell indicating to the user the profile associated with that cell is now the selected profile. It also sets that cell's associated OSCProfile object's 'isSelected' property to YES  */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:0];
    NSIndexPath *lastSelectedIndexPath = [NSIndexPath indexPathForRow:[profilesManager getIndexOfSelectedProfile] inSection:0];

    if (selectedIndexPath != lastSelectedIndexPath) {
        /* Place checkmark on selected cell and set profile associated with cell as selected profile */
        UITableViewCell *selectedCell = [tableView cellForRowAtIndexPath: selectedIndexPath];
        selectedCell.accessoryType = UITableViewCellAccessoryCheckmark;  // add checkmark to the cell the user tapped
        OSCProfile *profile = [[profilesManager getAllProfiles] objectAtIndex:indexPath.row];
        [profilesManager setProfileToSelected: profile.name];   // set the profile associated with this cell's 'isSelected' property to YES
        
        /* Remove checkmark on the previously selected cell  */
        UITableViewCell *lastSelectedCell = [tableView cellForRowAtIndexPath: lastSelectedIndexPath];
        lastSelectedCell.accessoryType = UITableViewCellAccessoryNone; 
        [tableView deselectRowAtIndexPath:lastSelectedIndexPath animated:YES];
    }
}


@end
