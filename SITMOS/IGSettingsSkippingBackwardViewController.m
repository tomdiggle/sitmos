//
//  IGSettingsSkippingBackwardViewController.m
//  SITMOS
//
//  Created by Tom Diggle on 24/02/2013.
//
//

#import "IGSettingsSkippingBackwardViewController.h"

#import "IGDefines.h"

@interface IGSettingsSkippingBackwardViewController ()

@property (nonatomic, strong) NSArray *skippingBackwardTimes;

@end

@implementation IGSettingsSkippingBackwardViewController

- (void)viewDidLayoutSubviews
{
    self.view.backgroundColor = kRGBA(245.0f, 245.0f, 245.0f, 1);
    self.tableView.backgroundView = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"SkippingBackward", @"text label for skipping backward")];
    
    _skippingBackwardTimes = @[@10, @15, @30, @45];
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
    [[cell textLabel] setText:[NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [[_skippingBackwardTimes objectAtIndex:indexPath.row] integerValue]]];
    
    if ([[self currentSkippingBackwardTime] isEqualToNumber:[_skippingBackwardTimes objectAtIndex:indexPath.row]])
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
    NSInteger currentIndex = [_skippingBackwardTimes indexOfObject:[self currentSkippingBackwardTime]];
    NSIndexPath *currentIndexPath = [NSIndexPath indexPathForRow:currentIndex
                                                       inSection:0];
    UITableViewCell *currentCheckedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
    [currentCheckedCell setAccessoryType:UITableViewCellAccessoryNone];
    
    // Checkmark the currently selected setting
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    
    [self setSettingSkippingBackwardTime:[_skippingBackwardTimes objectAtIndex:indexPath.row]];
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
    
    // Pop view controller
    [[self navigationController] popViewControllerAnimated:YES];
}

#pragma mark - Skipping Backward

- (NSNumber *)currentSkippingBackwardTime
{
    return [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingBackwardTime]];
}

- (void)setSettingSkippingBackwardTime:(NSNumber *)time
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:[time integerValue]
                          forKey:IGSettingSkippingBackwardTime];
    [userDefaults synchronize];
}

@end
