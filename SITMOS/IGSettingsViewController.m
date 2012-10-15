/**
 * Copyright (c) 2012, Tom Diggle
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
#import "IGSettingsEpisodesDeleteViewController.h"
#import "IGEpisode.h"

@implementation IGSettingsViewController

- (void)viewDidLayoutSubviews
{
    self.view.backgroundColor = kRGBA(245.0f, 245.0f, 245.0f, 1);
    self.tableView.backgroundView = nil;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"Settings", @"text label for settings")];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"text label for done")
                                                                   style:UIBarButtonItemStyleBordered
                                                                  target:self
                                                                  action:@selector(doneButtonTapped:)];
    [[self navigationItem] setRightBarButtonItem:doneButton];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.tableView reloadData];
}

#pragma mark - UITableViewSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0)
    {
        return 2;
    }
    else if (section == 1)
    {
        return 2;
    }
    else if (section == 2)
    {
        return 1;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const basicCellIdentifier = @"basicCellIdentifier";
    static NSString * const rightDetailCellIdentifier = @"rightDetailCellIdentifier";
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    UISwitch *switchView = [[UISwitch alloc] initWithFrame:CGRectZero];
    if (indexPath.section == 0)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:basicCellIdentifier];
        if (!cell)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:basicCellIdentifier];
        }
        [cell setBackgroundColor:kRGBA(240.0f, 240.0f, 240.0f, 1)];
        [[cell textLabel] setTextColor:kRGBA(41.0f, 41.0f, 41.0f, 1)];
        [[cell textLabel] setFont:[UIFont fontWithName:IGFontNameMedium
                                                  size:17.0f]];
        [cell setSelectionStyle:UITableViewCellEditingStyleNone];

        if (indexPath.row == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"Streaming", @"text label for streaming")];
            [cell setAccessoryView:switchView];
            [switchView setOn:[userDefaults boolForKey:IGSettingCellularDataStreaming]];
            [switchView addTarget:self action:@selector(updateSettingCellularDataStreaming:) forControlEvents:UIControlEventTouchUpInside];
        }
        else
        {
            [[cell textLabel] setText:NSLocalizedString(@"Downloading", @"text label for downloading")];
            [switchView setOn:[userDefaults boolForKey:IGSettingCellularDataDownloading]];
            [switchView addTarget:self action:@selector(updateSettingCellularDataDownloading:) forControlEvents:UIControlEventTouchUpInside];
            [cell setAccessoryView:switchView];
        }
        
        return cell;
    }
    else if (indexPath.section == 1)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:rightDetailCellIdentifier];
        if (!cell)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:rightDetailCellIdentifier];
        }
        [cell setBackgroundColor:kRGBA(240.0f, 240.0f, 240.0f, 1)];
        [[cell textLabel] setFont:[UIFont fontWithName:IGFontNameMedium
                                                  size:17.0f]];
        [[cell detailTextLabel] setFont:[UIFont fontWithName:IGFontNameRegular
                                                        size:17.0f]];
        [[cell detailTextLabel] setTextColor:kRGBA(153.0f, 153.0f, 153.0f, 1)];
       
        if (indexPath.row == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"UnplayedBadge", @"text label for unplayed episode badge")];
            [switchView setOn:[userDefaults boolForKey:IGSettingUnseenBadge]];
            [switchView addTarget:self action:@selector(updateSettingUnseenBadge:) forControlEvents:UIControlEventTouchUpInside];
            [cell setAccessoryView:switchView];
        }
        else
        {
            [cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
            [[cell textLabel] setText:NSLocalizedString(@"Delete", @"text label for delete")];
            [[cell detailTextLabel] setText:[userDefaults boolForKey:IGSettingEpisodesDelete] ? NSLocalizedString(@"Automatically", @"text label for automatically") : NSLocalizedString(@"Never", @"text label for never")];
        }
        
        return cell;
    }
    else if (indexPath.section == 2)
    {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:basicCellIdentifier];
        if (!cell)
        {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:basicCellIdentifier];
        }
        [cell setBackgroundColor:kRGBA(240.0f, 240.0f, 240.0f, 1)];
        [[cell textLabel] setTextColor:kRGBA(41.0f, 41.0f, 41.0f, 1)];
        [[cell textLabel] setTextAlignment:NSTextAlignmentCenter];
        [[cell textLabel] setFont:[UIFont fontWithName:IGFontNameMedium
                                                  size:17.0f]];
        if (indexPath.row == 0)
        {
            [[cell textLabel] setText:NSLocalizedString(@"ReviewOnAppStore", @"text label for review on the app store")];
        }
        
        return cell;
    }

    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0 || section == 1)
    {
        return 44.0f;
    }
    
    return 0.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 2) return nil;
    
    UIView *viewHeader = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44.0f)];
    UILabel *labelHeader = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 0, viewHeader.frame.size.width, viewHeader.frame.size.height)];
    [labelHeader setFont:[UIFont fontWithName:IGFontNameMedium
                                   size:17.0f]];
    [labelHeader setTextColor:kRGBA(41.0f, 41.0f, 41.0f, 1)];
    [labelHeader setBackgroundColor:[UIColor clearColor]];
    if (section == 0)
    {
        [labelHeader setText:NSLocalizedString(@"CellularData", @"text label for cellular data")];
    }
    else if (section == 1)
    {
        [labelHeader setText:NSLocalizedString(@"Episodes", @"text label for episodes")];
    }
    [viewHeader addSubview:labelHeader];
    
    return viewHeader;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == 1 || section == 2)
    {
        return 60.0f;
    }
    
    return 0.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 0) return nil;
    
    UIView *viewFooter = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60.0f)];
    UILabel *labelFooter = [[UILabel alloc] initWithFrame:CGRectMake(20.0f, 0, viewFooter.frame.size.width - 40.0f, viewFooter.frame.size.height)];
    [labelFooter setFont:[UIFont fontWithName:IGFontNameRegular
                                         size:14.0f]];
    [labelFooter setTextColor:kRGBA(153.0f, 153.0f, 153.0f, 1)];
    [labelFooter setBackgroundColor:[UIColor clearColor]];
    [labelFooter setTextAlignment:NSTextAlignmentCenter];
    [labelFooter setLineBreakMode:NSLineBreakByWordWrapping];
    [labelFooter setNumberOfLines:2];
    if (section == 1)
    {
        [labelFooter setText:NSLocalizedString(@"SettingsEpisodesSectionFooter", @"text label for settings episodes section footer")];
    }
    else if (section == 2)
    {
        [labelFooter setText:[NSString stringWithFormat:@"%@ %@", NSLocalizedString(@"Version", @"textLabel for version"), [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]]];
    }
    [viewFooter addSubview:labelFooter];
    
    return viewFooter;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 1)
    {
        if (indexPath.row == 1)
        {
            IGSettingsEpisodesDeleteViewController *episodesDeleteViewController = [[IGSettingsEpisodesDeleteViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [[self navigationController] pushViewController:episodesDeleteViewController
                                                   animated:YES];
        }
    }
    else if (indexPath.section == 2)
    {
        if (indexPath.row == 0)
        {
            // Review on the App Store
            NSString *appStoreLink = @"itms://itunes.apple.com/app/id567269025";
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:appStoreLink]];
        }
    }
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
}

#pragma mark - IBAction

- (IBAction)doneButtonTapped:(id)sender
{
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

#pragma mark - Update Setting Method

- (void)updateSettingCellularDataStreaming:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:[sender isOn] forKey:IGSettingCellularDataStreaming];
}

- (void)updateSettingCellularDataDownloading:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:[sender isOn] forKey:IGSettingCellularDataDownloading];
}

- (void)updateSettingUnseenBadge:(id)sender
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:[sender isOn] forKey:IGSettingUnseenBadge];
    
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
