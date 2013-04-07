/**
 * Copyright (c) 2013, Tom Diggle
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

#import "IGSettingsViewController.h"
#import "IGEpisode.h"
#import "IGSettingsSkippingBackwardViewController.h"
#import "IGSettingsSkippingForwardViewController.h"
#import "IGSettingsEpisodesDeleteViewController.h"

typedef enum {
    IGSettingsTableViewSectionCellularData = 0,
    IGSettingsTableViewSectionPlayback = 1,
    IGSettingsTableViewSectionEpisodes = 2,
    IGSettingsTableViewSectionMisc = 3
} IGSettingsTableViewSection;

@interface IGSettingsViewController ()

@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation IGSettingsViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _userDefaults = [NSUserDefaults standardUserDefaults];

    [[UILabel appearanceWhenContainedIn:[UITableViewHeaderFooterView class], nil] setColor:kRGBA(41.f, 41.f, 41.f, 1)];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDefaultsChanged:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
    
#ifdef TESTING
    // During testing mode a feedback button will be displayed at the top left of the nav bar
    UIBarButtonItem *feedbackButton = [[UIBarButtonItem alloc] initWithTitle:@"Feedback"
                                                                       style:UIBarButtonItemStyleBordered
                                                                      target:self
                                                                      action:@selector(launchFeedback)];
    [[self navigationItem] setLeftBarButtonItem:feedbackButton];
#endif
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - UITableViewDataSource Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    
    UISwitch *accessoryViewSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    if ([indexPath section] == IGSettingsTableViewSectionCellularData)
    {
        if ([indexPath row] == 0)
        {
            [cell setAccessoryView:accessoryViewSwitch];
            [accessoryViewSwitch setOn:[_userDefaults boolForKey:IGSettingCellularDataStreaming]];
            [accessoryViewSwitch addTarget:self
                                    action:@selector(updateSettingCellularDataStreaming:)
                          forControlEvents:UIControlEventTouchUpInside];
        }
        else if ([indexPath row] == 1)
        {
            [cell setAccessoryView:accessoryViewSwitch];
            [accessoryViewSwitch setOn:[_userDefaults boolForKey:IGSettingCellularDataDownloading]];
            [accessoryViewSwitch addTarget:self
                                    action:@selector(updateSettingCellularDataDownloading:)
                          forControlEvents:UIControlEventTouchUpInside];
        }
    }
    else if ([indexPath section] == IGSettingsTableViewSectionPlayback)
    {
        if ([indexPath row] == 0)
        {
            NSString *skippingBackwardTime = [NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [_userDefaults integerForKey:IGSettingSkippingBackwardTime]];
            [[cell detailTextLabel] setText:skippingBackwardTime];
        }
        else if ([indexPath row] == 1)
        {
            NSString *skippingForwardTime = [NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [_userDefaults integerForKey:IGSettingSkippingForwardTime]];
            [[cell detailTextLabel] setText:skippingForwardTime];
        }
    }
    else if ([indexPath section] == IGSettingsTableViewSectionEpisodes)
    {
        if ([indexPath row] == 0)
        {
            [cell setAccessoryView:accessoryViewSwitch];
            [accessoryViewSwitch setOn:[_userDefaults boolForKey:IGSettingUnseenBadge]];
            [accessoryViewSwitch addTarget:self
                                    action:@selector(updateSettingCellularDataStreaming:)
                          forControlEvents:UIControlEventTouchUpInside];
        }
        else if ([indexPath row] == 1)
        {
            [[cell detailTextLabel] setText:[_userDefaults boolForKey:IGSettingEpisodesDelete] ? NSLocalizedString(@"Automatically", @"text label for automatically") : NSLocalizedString(@"Never", @"text label for never")];
        }
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *footerTitle = nil;
    if (section == IGSettingsTableViewSectionEpisodes)
    {
        footerTitle = NSLocalizedString(@"SettingsEpisodesSectionFooter", @"text label for settings episodes section footer");
    }
    else if (section == IGSettingsTableViewSectionMisc)
    {
        footerTitle = [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Version", @"textLabel for version"), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
    }
    
    return footerTitle;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == IGSettingsTableViewSectionPlayback)
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
    else if ([indexPath section] == IGSettingsTableViewSectionEpisodes)
    {
        if ([indexPath row] == 1)
        {
            IGSettingsEpisodesDeleteViewController *episodesDeleteViewController = [[IGSettingsEpisodesDeleteViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [[self navigationController] pushViewController:episodesDeleteViewController
                                                   animated:YES];
        }
    }
    else if ([indexPath section] == IGSettingsTableViewSectionMisc)
    {
        if ([indexPath row] == 0)
        {
            // Review on the App Store
            NSString *appStoreLink = @"itms://itunes.apple.com/app/id567269025";
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appStoreLink]];
        }
        else if ([indexPath row] == 1)
        {
            [self followSitmosOnTwitter];
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

#pragma mark - Follow SITMOS on Twitter

- (void)followSitmosOnTwitter
{
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"tweetbot:///user_profile/sitmos"]])
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"tweetbot:///user_profile/sitmos"]];
    }
    else if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://user?screen_name=sitmos"]])
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"twitter://user?screen_name=sitmos"]];
    }
    else
    {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://twitter.com/sitmos"]];
    }
}

#pragma mark - Done Button

- (IBAction)doneButtonTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

#pragma mark - Feedback
#ifdef TESTING
- (IBAction)launchFeedback
{
    [TestFlight openFeedbackView];
}
#endif

@end
