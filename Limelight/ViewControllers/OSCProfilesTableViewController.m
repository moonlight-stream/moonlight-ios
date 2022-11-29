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

@implementation OSCProfilesTableViewController

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
    
    
}

- (void)addNavBar {
    
    UINavigationBar* navbar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, NAV_BAR_HEIGHT)];

    UINavigationItem* navItem = [[UINavigationItem alloc] initWithTitle:@"On Screen Controller Profiles"];
    UIBarButtonItem* cancelBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(onTapCancel:)];
    navItem.leftBarButtonItem = cancelBtn;

    UIBarButtonItem* doneBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(onTapDone:)];
    navItem.rightBarButtonItem = doneBtn;

    [navbar setItems:@[navItem]];
    [self.view addSubview:navbar];
}

-(void)onTapDone:(UIBarButtonItem*)item{

}

-(void)onTapCancel:(UIBarButtonItem*)item{

    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    
    return [self.OSCProfiles count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    cell.textLabel.text = self.OSCProfiles[indexPath.row];
    return cell;
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
