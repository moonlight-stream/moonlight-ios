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

- (IBAction)doneTapped:(id)sender {
    
    [self dismissViewControllerAnimated:YES completion:nil];

    if (self.didDismiss) {
        self.didDismiss();
    }
}

#pragma mark DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.OSCProfiles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    ProfileTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    cell.name.text = self.OSCProfiles[indexPath.row];
    
    if ([self.OSCProfiles[indexPath.row] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"]]) {
        
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        lastIndexPath = indexPath;
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
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        [self.OSCProfiles removeObjectAtIndex:indexPath.row];

        [[NSUserDefaults standardUserDefaults] setObject:self.OSCProfiles forKey:@"OSCProfileNames"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
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
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
        
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *selectedOSCProfile = self.OSCProfiles[indexPath.row];
    [userDefaults setObject:selectedOSCProfile forKey:@"SelectedOSCProfile"];
    [userDefaults synchronize];
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
