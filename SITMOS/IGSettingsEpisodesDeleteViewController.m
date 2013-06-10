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

#import "IGSettingsEpisodesDeleteViewController.h"

#import "IGDefines.h"

@implementation IGSettingsEpisodesDeleteViewController

- (void)viewDidLayoutSubviews
{
    [[self view] setBackgroundColor:kRGBA(240, 240, 240, 1)];
    [[self tableView] setBackgroundView:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"Delete", @"text label for delete")];
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
    return 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"cellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [[cell textLabel] setFont:[UIFont boldSystemFontOfSize:16.f]];
    [cell setBackgroundColor:kRGBA(245, 245, 245, 1)];
    
    if (indexPath.row == 0)
    {
        [[cell textLabel] setText:NSLocalizedString(@"Never", @"text label for never")];
        if (![userDefaults boolForKey:IGSettingEpisodesDelete])
        {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }
    else
    {
        [[cell textLabel] setText:NSLocalizedString(@"Automatically", @"text label for automatically")];
        if ([userDefaults boolForKey:IGSettingEpisodesDelete])
        {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Put a check mark to the setting selected, deselect the row and pop the view controller
    NSInteger currentIndex = indexPath.row == 0 ? 1 : 0;
    NSIndexPath *currentIndexPath = [NSIndexPath indexPathForRow:currentIndex
                                                inSection:0];
    UITableViewCell *currentCheckedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
    [currentCheckedCell setAccessoryType:UITableViewCellAccessoryNone];
    
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL episodeDelete = [userDefaults boolForKey:IGSettingEpisodesDelete] ? NO : YES;
    [userDefaults setBool:episodeDelete forKey:IGSettingEpisodesDelete];
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
    
    [[self navigationController] popViewControllerAnimated:YES];
}

@end
