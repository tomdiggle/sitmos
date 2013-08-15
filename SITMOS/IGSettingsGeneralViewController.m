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

#import "IGSettingsGeneralViewController.h"

#import "IGEpisode.h"
#import "IGSettingsSkippingBackwardViewController.h"
#import "IGSettingsSkippingForwardViewController.h"
#import "IGSettingsEpisodesDeleteViewController.h"
#import "IGDefines.h"
//#import "CoreData+MagicalRecord.h"

@interface IGSettingsGeneralViewController ()

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation IGSettingsGeneralViewController

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [[self view] setBackgroundColor:kRGBA(240, 240, 240, 1)];
    [[self tableView] setBackgroundView:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"General", @"text label for general")];
    
    _userDefaults = [NSUserDefaults standardUserDefaults];
    
//    [[UILabel appearanceWhenContainedIn:[UITableViewHeaderFooterView class], nil] setColor:kRGBA(41.f, 41.f, 41.f, 1)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDefaultsChanged:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Orientation Support

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
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
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1
                                      reuseIdentifier:cellIdentifier];
    }
    
    UISwitch *accessoryViewSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    if ([indexPath section] == 0)
    {
        if ([indexPath row] == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"Streaming", @"text label for streaming")];
            [cell setAccessoryView:accessoryViewSwitch];
            [accessoryViewSwitch setOn:[_userDefaults boolForKey:IGSettingCellularDataStreaming]];
            [accessoryViewSwitch addTarget:self
                                    action:@selector(updateSettingCellularDataStreaming:)
                          forControlEvents:UIControlEventTouchUpInside];
        }
        else if ([indexPath row] == 1)
        {
            [[cell textLabel] setText:NSLocalizedString(@"Downloading", @"text label for downloading")];
            [cell setAccessoryView:accessoryViewSwitch];
            [accessoryViewSwitch setOn:[_userDefaults boolForKey:IGSettingCellularDataDownloading]];
            [accessoryViewSwitch addTarget:self
                                    action:@selector(updateSettingCellularDataDownloading:)
                          forControlEvents:UIControlEventTouchUpInside];
        }
    }
    else if ([indexPath section] == 1)
    {
        if ([indexPath row] == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"SkippingBackward", @"text label for skipping backward")];
            NSString *skippingBackwardTime = [NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [_userDefaults integerForKey:IGSettingSkippingBackwardTime]];
            [[cell detailTextLabel] setText:skippingBackwardTime];
            [[cell detailTextLabel] setTextColor:kRGBA(41.f, 41.f, 41.f, 1)];
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
        else if ([indexPath row] == 1)
        {
            [[cell textLabel] setText:NSLocalizedString(@"SkippingForward", @"text label for skipping forward")];
            NSString *skippingForwardTime = [NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [_userDefaults integerForKey:IGSettingSkippingForwardTime]];
            [[cell detailTextLabel] setText:skippingForwardTime];
            [[cell detailTextLabel] setTextColor:kRGBA(41.f, 41.f, 41.f, 1)];
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
    }
    else if ([indexPath section] == 2)
    {
        if ([indexPath row] == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"UnplayedBadge", @"text label for unplayed badge")];
            [cell setAccessoryView:accessoryViewSwitch];
            [accessoryViewSwitch setOn:[_userDefaults boolForKey:IGSettingUnseenBadge]];
            [accessoryViewSwitch addTarget:self
                                    action:@selector(updateSettingUnseenBadge:)
                          forControlEvents:UIControlEventTouchUpInside];
        }
        else if ([indexPath row] == 1)
        {
            [[cell textLabel] setText:NSLocalizedString(@"Delete", @"text label for delete")];
            [[cell detailTextLabel] setText:[_userDefaults boolForKey:IGSettingEpisodesDelete] ? NSLocalizedString(@"Automatically", @"text label for automatically") : NSLocalizedString(@"Never", @"text label for never")];
            [[cell detailTextLabel] setTextColor:kRGBA(41.f, 41.f, 41.f, 1)];
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == 0)
    {
        return NSLocalizedString(@"CellularData", @"text label for cellular data");
    }
    else if (section == 1)
    {
        return NSLocalizedString(@"Playback", @"text label for playback");
    }
    else
    {
        return NSLocalizedString(@"Episodes", @"text label for episodes");
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section != 2) return nil;
    
    return NSLocalizedString(@"SettingsEpisodesSectionFooter", @"text label for settings episodes section footer");
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 1)
    {
        if ([indexPath row] == 0)
        {
            IGSettingsSkippingBackwardViewController *skippingBackwardViewController = [[IGSettingsSkippingBackwardViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [[self navigationController] pushViewController:skippingBackwardViewController
                                                   animated:YES];
        }
        else if ([indexPath row] == 1)
        {
            IGSettingsSkippingForwardViewController *skippingForwardViewController = [[IGSettingsSkippingForwardViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [[self navigationController] pushViewController:skippingForwardViewController
                                                   animated:YES];
        }
    }
    else if ([indexPath section] == 2)
    {
        if ([indexPath row] == 1)
        {
            IGSettingsEpisodesDeleteViewController *episodesDeleteViewController = [[IGSettingsEpisodesDeleteViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [[self navigationController] pushViewController:episodesDeleteViewController
                                                   animated:YES];
        }
    }
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

#pragma mark - Update Setting Methods

- (void)userDefaultsChanged:(id)sender
{
    [[self tableView] reloadData];
}

- (void)updateSettingCellularDataStreaming:(UISwitch *)sender
{
    [_userDefaults setBool:[sender isOn] forKey:IGSettingCellularDataStreaming];
    [_userDefaults synchronize];
}

- (void)updateSettingCellularDataDownloading:(UISwitch *)sender
{
    [_userDefaults setBool:[sender isOn] forKey:IGSettingCellularDataDownloading];
    [_userDefaults synchronize];
}

- (void)updateSettingUnseenBadge:(UISwitch *)sender
{
    [_userDefaults setBool:[sender isOn] forKey:IGSettingUnseenBadge];
    [_userDefaults synchronize];
    
    if ([sender isOn])
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"played == NO"];
        NSUInteger numberOfUnplayedEpisodes = [IGEpisode MR_countOfEntitiesWithPredicate:predicate];
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:numberOfUnplayedEpisodes];
    }
    else
    {
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:0];
    }
}

@end
