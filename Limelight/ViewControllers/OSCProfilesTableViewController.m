//
//  OSCProfilesTableViewController.m
//  Moonlight
//
//  Created by Long Le on 11/28/22.
//  Copyright © 2022 Moonlight Game Streaming Project. All rights reserved.
//

#import "OSCProfilesTableViewController.h"

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
    
    [self addNavBar];
    
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 0, NAV_BAR_HEIGHT)];

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    OSCProfiles = [[NSMutableArray alloc] init];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    
    self.OSCProfiles = [userDefaults objectForKey:@"OSCProfileNamesArray"];
    
    NSInteger profileIndexPosition = [self indexPositionForSelectedOSCProfile: [userDefaults objectForKey:@"SelectedOSCProfile"]];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:profileIndexPosition inSection:0];

    [self.tableView selectRowAtIndexPath:indexPath
                                animated:NO
                          scrollPosition:UITableViewScrollPositionNone];
    [self tableView:self.tableView didSelectRowAtIndexPath:indexPath];
}

- (void)addNavBar {
    
    UINavigationBar* navbar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, NAV_BAR_HEIGHT)];

    UINavigationItem* navItem = [[UINavigationItem alloc] initWithTitle:@"On Screen Controller Profiles"];

    UIBarButtonItem* doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onTapDone:)];
    navItem.rightBarButtonItem = doneBtn;

    [navbar setItems:@[navItem]];
    [self.view addSubview:navbar];
}

-(void)onTapDone:(UIBarButtonItem*)item{

    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.OSCProfiles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    NSString *profileNameWithSpaces = [self.OSCProfiles[indexPath.row] stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    cell.textLabel.text = profileNameWithSpaces;
    
    if ([self.OSCProfiles[indexPath.row] isEqualToString:[[NSUserDefaults standardUserDefaults] objectForKey:@"SelectedOSCProfile"]]) {
        
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        lastIndexPath = indexPath;
    }
    else {
        
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

-(NSInteger)indexPositionForSelectedOSCProfile: (NSString*)name {
    
    NSMutableArray *OSCProfilesNamesFromUserDefaultsArray = [[NSMutableArray alloc] init];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    OSCProfilesNamesFromUserDefaultsArray = [userDefaults objectForKey:@"OSCProfileNamesArray"];
    
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
    [userDefaults setObject:self.OSCProfiles[indexPath.row] forKey:@"SelectedOSCProfile"];
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
