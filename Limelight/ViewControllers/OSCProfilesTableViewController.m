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
    
    NSIndexPath *lastIndexPath;
}

@synthesize tableView;
@synthesize OSCProfiles;

- (void)viewDidLoad {
    
    [super viewDidLoad];
    // Do any additional setup after loading the view.
        
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    // Register the nib file with the table view
    [self.tableView registerNib:[UINib nibWithNibName:@"ProfileTableViewCell" bundle:nil] forCellReuseIdentifier:@"Cell"];
    
    self.OSCProfiles = [[NSMutableArray alloc] init];
    [self.OSCProfiles addObjectsFromArray: [[NSUserDefaults standardUserDefaults] objectForKey:@"OSCProfileNames"]];
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear: animated];
    
    if ([self.OSCProfiles count] > 0) { //scroll to selected profile if user has any saved profiles
        
        NSInteger profileIndexPosition = [self indexPositionForSelectedOSCProfile: [[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"]];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:profileIndexPosition inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

- (IBAction)loadTapped:(id)sender {
    
    if ([self.OSCProfiles count] > 0) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *selectedOSCProfile = [self.OSCProfiles objectAtIndex:lastIndexPath.row];
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
    
    if ([self.OSCProfiles count] == 0) {    //if user deleted all profiles this will create another 'Default' profile with Moonlight's legacy 'Full' OSC layout
        
        if (self.didDismiss) {
            self.didDismiss();
        }
    }
}

#pragma mark DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.OSCProfiles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.name.text = self.OSCProfiles[indexPath.row];
    
    if ([self.OSCProfiles[indexPath.row] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"]]) { //if this cell contains the name of the currently selected OSC profile then add a checkmark to the right side of the cell
        
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        lastIndexPath = indexPath;  //keeps track of which cell contains the currently selected OSC profile
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
    
    if ([self.OSCProfiles[indexPath.row] isEqualToString:@"Default"]) {   //If user is attempting to delete the 'Default' profile then show pop up telling user they can't delete the default profile
        
        UIAlertController * alertController = [UIAlertController alertControllerWithTitle: [NSString stringWithFormat:@""] message: @"Deleting the 'Default' profile is not allowed" preferredStyle:UIAlertControllerStyleAlert];
        
        [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            [alertController dismissViewControllerAnimated:NO completion:nil];
        }]];
        
        [self presentViewController:alertController animated:YES completion:nil];
        
        return;
    }
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *profile = [self.OSCProfiles objectAtIndex:indexPath.row];
        
        [userDefaults removeObjectForKey:[NSString stringWithFormat:@"%@-ButtonsLayout", profile]]; //Delete profile's corresponding array of 'OnScreenButtonState' objects from persistant storage
        
        //Delete profile name from persistant storage
        [self.OSCProfiles removeObjectAtIndex:indexPath.row];
        [userDefaults setObject:self.OSCProfiles forKey:@"OSCProfileNames"];
        
        if (indexPath.row == lastIndexPath.row) {   //if user is deleting the currently selected OSC profile then make the previous profile the currently selected OSC profile
            
            if (indexPath.row > 0) {
                
                [userDefaults setObject:[self.OSCProfiles objectAtIndex:indexPath.row - 1] forKey:@"SelectedOSCProfile"];
            }
        }

        [userDefaults synchronize];
        
        [tableView reloadData]; 
    }
}

-(NSInteger)indexPositionForSelectedOSCProfile: (NSString*)name {
    
    NSMutableArray *OSCProfilesNamesFromUserDefaultsArray = [[NSMutableArray alloc] init];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    OSCProfilesNamesFromUserDefaultsArray = [userDefaults objectForKey:@"OSCProfileNames"];
    
    for (int i = 0; i < [OSCProfilesNamesFromUserDefaultsArray count]; i++) {
        
        if ([name isEqualToString:OSCProfilesNamesFromUserDefaultsArray[i]]) {
            
            return i;
        }
    }
    
    return 0;
}


#pragma mark Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger newRow = [indexPath row];
    NSInteger oldRow = [lastIndexPath row];

    if (newRow != oldRow)
    {
        UITableViewCell *newCell = [tableView cellForRowAtIndexPath: indexPath];
        newCell.accessoryType = UITableViewCellAccessoryCheckmark;

        UITableViewCell *oldCell = [tableView cellForRowAtIndexPath: lastIndexPath];
        oldCell.accessoryType = UITableViewCellAccessoryNone;

        lastIndexPath = indexPath;
    
        [[NSUserDefaults standardUserDefaults] setObject:self.OSCProfiles[lastIndexPath.row] forKey:@"SelectedOSCProfile"];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
