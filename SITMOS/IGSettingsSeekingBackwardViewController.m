/**
 * Copyright (c) 2012-2013, Tom Diggle
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the Software
 * is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 * INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 * PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "IGSettingsSeekingBackwardViewController.h"

#import "IGDefines.h"

@interface IGSettingsSeekingBackwardViewController ()

@property (nonatomic, strong) NSArray *seekingBackwardTimes;

@end

@implementation IGSettingsSeekingBackwardViewController

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.seekingBackwardTimes = @[@10, @15, @30, @45];
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
    static NSString *cellIdentifier = @"cellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier
                                                            forIndexPath:indexPath];
    
    [[cell textLabel] setText:[NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [[self.seekingBackwardTimes objectAtIndex:indexPath.row] integerValue]]];
    
    if ([[self currentSkippingBackwardTime] isEqualToNumber:[self.seekingBackwardTimes objectAtIndex:indexPath.row]])
    {
        [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

/**
 * Checkmark then newly selected setting, remove the checkmark from the old setting.
 */
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view cell which is currently checkmarked
    NSInteger currentIndex = [_seekingBackwardTimes indexOfObject:[self currentSkippingBackwardTime]];
    NSIndexPath *currentIndexPath = [NSIndexPath indexPathForRow:currentIndex
                                                       inSection:0];
    UITableViewCell *currentCheckedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
    [currentCheckedCell setAccessoryType:UITableViewCellAccessoryNone];
    
    // Checkmark the currently selected setting
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    
    [self setSettingSkippingBackwardTime:[self.seekingBackwardTimes objectAtIndex:indexPath.row]];
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

#pragma mark - Skipping Backward

- (NSNumber *)currentSkippingBackwardTime
{
    return [NSNumber numberWithInteger:[[NSUserDefaults standardUserDefaults] integerForKey:IGPlayerSkipBackPeriodKey]];
}

- (void)setSettingSkippingBackwardTime:(NSNumber *)time
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setInteger:[time integerValue]
                          forKey:IGPlayerSkipBackPeriodKey];
    [userDefaults synchronize];
}

@end
