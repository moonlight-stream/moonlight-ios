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

    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSError *error;
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: &error];
    
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        [self.OSCProfiles addObject: profileDecoded];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear: animated];
    
    if ([self.OSCProfiles count] > 0) { //scroll to selected profile if user has any saved profiles
        
        OSCProfile *selectedOSCProfile = [self selectedOSCProfile];
        NSUInteger index = [self.OSCProfiles indexOfObject:selectedOSCProfile];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [self.tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
    }
}

#pragma mark - UIButton Actions

- (IBAction)loadTapped:(id)sender {
    
    if ([self.OSCProfiles count] > 0) {
        
        OSCProfile *profile = [self.OSCProfiles objectAtIndex:selectedIndexPath.row];
        [self setOSCProfileAsSelectedWithName: profile.name];
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


- (OSCProfile *)selectedOSCProfile {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    OSCProfile *profileDecoded;
    for (NSData *profileEncoded in profilesEncoded) {
        
        profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:profileEncoded error:nil];
        
        if (profileDecoded.isSelected) {
            
            return profileDecoded;
        }
    }
    
    return nil;
}

- (void) setOSCProfileAsSelectedWithName: (NSString *)name {
    
    NSData *encodedProfiles = [[NSUserDefaults standardUserDefaults] objectForKey: @"OSCProfiles"];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSMutableData class], [NSMutableArray class], [OSCProfile class], [OnScreenButtonState class], nil];
    NSMutableArray *profilesEncoded = [NSKeyedUnarchiver unarchivedObjectOfClasses:classes fromData:encodedProfiles error: nil];
    
    NSMutableArray *profilesDecoded = [[NSMutableArray alloc] init];
    for (NSData *profileEncoded in profilesEncoded) {
        
        OSCProfile *profileDecoded = [NSKeyedUnarchiver unarchivedObjectOfClasses: classes fromData:profileEncoded error: nil];
        [profilesDecoded addObject: profileDecoded];
    }
    
    for (OSCProfile *profile in profilesDecoded) {
                
        if ([profile.name isEqualToString:name]) {
            
            profile.isSelected = YES;
        }
        else {
            
            profile.isSelected = NO;
        }
    }
    
    [profilesEncoded removeAllObjects];
    for (OSCProfile *profileDecoded in profilesDecoded) {   //add encoded profiles back into an array
        
        NSData *profileEncoded = [NSKeyedArchiver archivedDataWithRootObject:profileDecoded requiringSecureCoding:YES error:nil];
        [profilesEncoded addObject:profileEncoded];
    }
        
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:profilesEncoded requiringSecureCoding:YES error:nil];
    
    [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

#pragma mark - TableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.OSCProfiles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    OSCProfile *profile = self.OSCProfiles[indexPath.row];
    cell.name.text = profile.name;
    
    if ([profile.name isEqualToString: [self selectedOSCProfile].name]) { //if this cell contains the name of the currently selected OSC profile then add a checkmark to the right side of the cell
        
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
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.OSCProfiles requiringSecureCoding:YES error:nil];
        
        [[NSUserDefaults standardUserDefaults] setObject:data forKey:@"OSCProfiles"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [tableView reloadData]; 
    }
}

#pragma mark - TableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger newRow = [indexPath row];
    NSInteger oldRow = [selectedIndexPath row];

    if (newRow != oldRow) {
        
        UITableViewCell *newCell = [tableView cellForRowAtIndexPath: indexPath];
        newCell.accessoryType = UITableViewCellAccessoryCheckmark;

        UITableViewCell *oldCell = [tableView cellForRowAtIndexPath: selectedIndexPath];
        oldCell.accessoryType = UITableViewCellAccessoryNone;

        selectedIndexPath = indexPath;
        
        OSCProfile *profile = self.OSCProfiles[indexPath.row];
        [self setOSCProfileAsSelectedWithName: profile.name];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
