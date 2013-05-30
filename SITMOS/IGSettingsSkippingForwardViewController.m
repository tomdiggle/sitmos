//
//  IGSettingsSkippingForwardViewController.m
//  SITMOS
//
//  Created by Tom Diggle on 24/02/2013.
//
//

#import "IGSettingsSkippingForwardViewController.h"

#import "IGDefines.h"

@interface IGSettingsSkippingForwardViewController ()

@property (nonatomic, strong) NSArray *skippingForwardTimes;

@end

@implementation IGSettingsSkippingForwardViewController

- (void)viewDidLayoutSubviews
{
    self.view.backgroundColor = kRGBA(245.0f, 245.0f, 245.0f, 1);
    self.tableView.backgroundView = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setTitle:NSLocalizedString(@"SkippingForward", @"text label for skipping forward")];
    
    _skippingForwardTimes = @[@10, @15, @30, @45];
}

#pragma mark - Orientation Support

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 4;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    [cell setBackgroundColor:kRGBA(240.0f, 240.0f, 240.0f, 1)];
    [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:16.f]];
    [[cell textLabel] setText:[NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [[_skippingForwardTimes objectAtIndex:indexPath.row] integerValue]]];
    
    if ([[self currentSkippingForwardTime] isEqualToNumber:[_skippingForwardTimes objectAtIndex:indexPath.row]])
    {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

/**
 * Checkmark then newly selected setting, remove the checkmark from the old setting and pop the view controller.
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view cell which is currently checkmarked
    NSInteger currentIndex = [_skippingForwardTimes indexOfObject:[self currentSkippingForwardTime]];
    NSIndexPath *currentIndexPath = [NSIndexPath indexPathForRow:currentIndex
                                                       inSection:0];
    UITableViewCell *currentCheckedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
    [currentCheckedCell setAccessoryType:UITableViewCellAccessoryNone];
    
    // Checkmark the currently selected setting
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    
    [self setSettingSkippingForwardTime:[_skippingForwardTimes objectAtIndex:indexPath.row]];
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
    
    // Pop view controller
    [[self navigationController] popViewControllerAnimated:YES];
}

#pragma mark - Skipping Forward

- (NSNumber *)currentSkippingForwardTime
{
    return [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingForwardTime]];
}

- (void)setSettingSkippingForwardTime:(NSNumber *)time
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:[time integerValue]
                      forKey:IGSettingSkippingForwardTime];
    [userDefaults synchronize];
}

@end
