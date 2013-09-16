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
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier
                                                            forIndexPath:indexPath];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (indexPath.row == 0)
    {
        [[cell textLabel] setText:NSLocalizedString(@"Never", @"text label for never")];
        if (![userDefaults boolForKey:IGAutoDeleteAfterFinishedPlayingKey])
        {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }
    else
    {
        [[cell textLabel] setText:NSLocalizedString(@"Automatically", @"text label for automatically")];
        if ([userDefaults boolForKey:IGAutoDeleteAfterFinishedPlayingKey])
        {
            [cell setAccessoryType:UITableViewCellAccessoryCheckmark];
        }
    }
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger currentIndex = indexPath.row == 0 ? 1 : 0;
    NSIndexPath *currentIndexPath = [NSIndexPath indexPathForRow:currentIndex
                                                inSection:0];
    UITableViewCell *currentCheckedCell = [tableView cellForRowAtIndexPath:currentIndexPath];
    [currentCheckedCell setAccessoryType:UITableViewCellAccessoryNone];
    
    [[tableView cellForRowAtIndexPath:indexPath] setAccessoryType:UITableViewCellAccessoryCheckmark];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL episodeDelete = [userDefaults boolForKey:IGAutoDeleteAfterFinishedPlayingKey] ? NO : YES;
    [userDefaults setBool:episodeDelete forKey:IGAutoDeleteAfterFinishedPlayingKey];
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

@end
