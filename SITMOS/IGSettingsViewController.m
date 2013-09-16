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

#import "IGSettingsViewController.h"

#import "IGHTTPClient.h"
#import "IGEpisode.h"
#import "IGDefines.h"

@interface IGSettingsViewController ()

@property (nonatomic, weak) IBOutlet UISwitch *cellularDataStreamingSwitch;
@property (nonatomic, weak) IBOutlet UISwitch *cellularDataDownloadingSwitch;
@property (nonatomic, weak) IBOutlet UISwitch *episodesUnplayedBadgeSwitch;
@property (nonatomic, strong) NSUserDefaults *userDefaults;

@end

@implementation IGSettingsViewController

#pragma mark - Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.userDefaults = [NSUserDefaults standardUserDefaults];
    
    [self.cellularDataStreamingSwitch setOn:[self.userDefaults boolForKey:IGAllowCellularDataStreamingKey]];
    [self.cellularDataDownloadingSwitch setOn:[self.userDefaults boolForKey:IGAllowCellularDataDownloadingKey]];
    [self.episodesUnplayedBadgeSwitch setOn:[self.userDefaults boolForKey:IGShowApplicationBadgeForUnseenKey]];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(userDefaultsChanged:)
                                                 name:NSUserDefaultsDidChangeNotification
                                               object:nil];
}

#pragma mark - Orientation Support

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - UITableViewDataSource Methods

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [super tableView:tableView
                       cellForRowAtIndexPath:indexPath];
    
    NSInteger section = indexPath.section;
    NSInteger row = indexPath.row;
    
    if (section == 1)
    {
        // Playback Section
        if (row == 0)
        {
            NSString *skippingBackwardTime = [NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [self.userDefaults integerForKey:IGPlayerSkipBackPeriodKey]];
            [[cell detailTextLabel] setText:skippingBackwardTime];
        }
        else if (row == 1)
        {
            NSString *skippingForwardTime = [NSString stringWithFormat:NSLocalizedString(@"Seconds", @"text label for seconds"), [self.userDefaults integerForKey:IGPlayerSkipForwardPeriodKey]];
            [[cell detailTextLabel] setText:skippingForwardTime];
        }
    }
    else if (section == 2)
    {
        // Episodes Section
        if (row == 1)
        {
            NSString *deleteMethod = [self.userDefaults boolForKey:IGAutoDeleteAfterFinishedPlayingKey] ? NSLocalizedString(@"Automatically", @"text label for automatically") : NSLocalizedString(@"Never", @"text label for never");
            [[cell detailTextLabel] setText:deleteMethod];
        }
    }
    
    return cell;
}

//- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
//{
//    return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Version", @"textLabel for version"), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
//}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 3)
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

#pragma mark - Update Settings

- (void)userDefaultsChanged:(id)sender
{
    [[self tableView] reloadData];
}

- (IBAction)updateSettingCellularDataStreaming:(id)sender
{
    [self.userDefaults setBool:[sender isOn] forKey:IGAllowCellularDataStreamingKey];
    [self.userDefaults synchronize];
}

- (IBAction)updateSettingCellularDataDownloading:(id)sender
{
    [self.userDefaults setBool:[sender isOn] forKey:IGAllowCellularDataDownloadingKey];
    [self.userDefaults synchronize];
}

- (IBAction)updateSettingPushNotifications:(id)sender
{
    [self.userDefaults setBool:[sender isOn] forKey:IGEnablePushNotificationsKey];
    [self.userDefaults synchronize];
    
    if (![sender isOn])
    {
        IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
        [httpClient unregisterPushNotificationsWithCompletion:^(NSError *error) {
            if (error)
            {
                NSLog(@"Error: %@", error);
                // Reset the setting
                [self.userDefaults setBool:([sender isOn] ? NO : YES)
                                forKey:IGEnablePushNotificationsKey];
                [self.userDefaults synchronize];
        
                // Reset the switch
                [sender setOn:([sender isOn] ? NO : YES)
                     animated:YES];
            }
        }];
    }
    else
    {
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
}

- (IBAction)updateSettingUnseenBadge:(id)sender
{
    [self.userDefaults setBool:[sender isOn] forKey:IGShowApplicationBadgeForUnseenKey];
    [self.userDefaults synchronize];
    
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
