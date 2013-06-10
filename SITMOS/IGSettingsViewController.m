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

#import "IGDefines.h"
#import "IGSettingsGeneralViewController.h"

@implementation IGSettingsViewController

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [[self view] setBackgroundColor:kRGBA(240, 240, 240, 1)];
    [[self tableView] setBackgroundView:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"Settings", @"text label for settings")];

    [[UILabel appearanceWhenContainedIn:[UITableViewHeaderFooterView class], nil] setColor:kRGBA(41.f, 41.f, 41.f, 1)];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(doneButtonTapped:)];
}

#pragma mark - Orientation Support

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 1;
    }
    else
    {
        return 2;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"cellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:cellIdentifier];
    }
    
    [cell setBackgroundColor:kRGBA(245, 245, 245, 1)];
    
    if ([indexPath section] == 0)
    {
        if ([indexPath section] == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"General", @"text label for general")];
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
        }
    }
    else if ([indexPath section] == 1)
    {
        if ([indexPath row] == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"ReviewOnAppStore", @"text label for review on app store")];
            [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
            [cell setAccessibilityTraits:UIAccessibilityTraitLink];
        }
        else if ([indexPath row] == 1)
        {
            [[cell textLabel] setText:NSLocalizedString(@"FollowSITMOSOnTwitter", @"text label for follow sitmos on twitter")];
            [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
            [cell setAccessibilityTraits:UIAccessibilityTraitLink];
        }
    }

    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section != 0) return nil;
    
    return NSLocalizedString(@"Settings", @"text label for settings");
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section != 1) return nil;
    
    return [NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Version", @"textLabel for version"), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([indexPath section] == 0)
    {
        if ([indexPath row] == 0)
        {
            IGSettingsGeneralViewController *settingsGeneralViewController = [[IGSettingsGeneralViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [[self navigationController] pushViewController:settingsGeneralViewController
                                                   animated:YES];
        }
    }
    else if ([indexPath section] == 1)
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

@end
