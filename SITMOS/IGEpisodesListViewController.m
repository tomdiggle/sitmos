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

#import "IGEpisodesListViewController.h"

#import "IGEpisodeCell.h"
#import "IGEpisode.h"
#import "IGAudioPlayerViewController.h"
#import "IGEpisodeShowNotesViewController.h"
#import "IGSettingsViewController.h"
#import "IGDefines.h"
#import "IGMediaPlayer.h"
#import "IGMediaAsset.h"
#import "SSPullToRefresh.h"
#import "RIButtonItem.h"
#import "UIActionSheet+Blocks.h"
#import "UIAlertView+Blocks.h"
#import "IGHTTPClient.h"
#import "AFDownloadRequestOperation.h"
#import "UIViewController+IGNowPlayingButton.h"
#import "TDNotificationPanel.h"
#import "TestFlight.h"

@interface IGEpisodesListViewController () <NSFetchedResultsControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, UIDataSourceModelAssociation, SSPullToRefreshViewDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSMutableArray *filteredEpisodeArray;
@property (nonatomic, strong) SSPullToRefreshView *pullToRefreshView;

@end

@implementation IGEpisodesListViewController

#pragma mark - View Lifecycle

- (void)viewWillLayoutSubviews
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self hideSearchBar];
        });
    });
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.fetchedResultsController = [IGEpisode MR_fetchAllSortedBy:@"pubDate"
                                                         ascending:NO
                                                     withPredicate:nil
                                                           groupBy:nil
                                                          delegate:self];
    
    self.searchDisplayController.searchResultsTableView.rowHeight = self.tableView.rowHeight;
    
    self.pullToRefreshView = [[SSPullToRefreshView alloc] initWithScrollView:self.tableView
                                                                    delegate:self];
    self.pullToRefreshView.contentView = [[SSPullToRefreshSimpleContentView alloc] init];
    self.pullToRefreshView.backgroundColor = [UIColor whiteColor];
    
    [self refreshPodcastFeedWithCompletionHandler:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ([self.tableView indexPathForSelectedRow])
    {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow]
                                      animated:YES];
    }
    
    if ([self.searchDisplayController.searchResultsTableView indexPathForSelectedRow])
    {
        [self.searchDisplayController.searchResultsTableView deselectRowAtIndexPath:[self.searchDisplayController.searchResultsTableView indexPathForSelectedRow]
                                                                           animated:YES];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self showNowPlayingButton];
}

#pragma mark - UIDataSourceModelAssociation

- (NSString *)modelIdentifierForElementAtIndexPath:(NSIndexPath *)idx inView:(UIView *)view
{
    NSString *identifier = nil;
    if (idx && view)
    {
        NSDictionary *episode = [self.fetchedResultsController objectAtIndexPath:idx];
        identifier = [episode valueForKey:@"title"];
    }
    
    return identifier;
}

- (NSIndexPath *)indexPathForElementWithModelIdentifier:(NSString *)identifier inView:(UIView *)view
{
    NSIndexPath *indexPath = nil;
    if (identifier && view)
    {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title == %@", identifier];
        NSInteger row = [[self.fetchedResultsController fetchedObjects] indexOfObjectPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            return [predicate evaluateWithObject:obj];
        }];
        
        if (row != NSNotFound)
        {
            indexPath = [NSIndexPath indexPathForRow:row inSection:0];
        }
    }
    
    return indexPath;
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
    if (tableView == self.searchDisplayController.searchResultsTableView)
    {
        return [self.filteredEpisodeArray count];
    }
    
    id <NSFetchedResultsSectionInfo> sectionInfo = nil;
    sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
	return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    IGEpisodeCell *episodeCell = (IGEpisodeCell *)[self.tableView dequeueReusableCellWithIdentifier:@"episodeCell"
                                                                                   forIndexPath:indexPath];
    
    IGEpisode *episode = nil;
    if (tableView == self.searchDisplayController.searchResultsTableView)
    {
        episode = [self.filteredEpisodeArray objectAtIndex:indexPath.row];
    }
    else
    {
        episode = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    
    [self updateEpisodeCell:episodeCell
                    episode:episode];
    
    [[episodeCell showNotesButton] setTag:indexPath.row];
    [[episodeCell downloadButton] setTag:indexPath.row];
    
    UIView *selectedBackgroundView = [[UIView alloc] init];
    [selectedBackgroundView setBackgroundColor:[UIColor colorWithRed:0.329 green:0.643 blue:0.901 alpha:1]];
    [episodeCell setSelectedBackgroundView:selectedBackgroundView];
    [episodeCell setAccessibilityTraits:UIAccessibilityTraitStartsMediaSession];
    
    return episodeCell;
}

#pragma mark - NSFetchResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
	[self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    NSArray *array = nil;
	switch (type)
    {
		case NSFetchedResultsChangeInsert:
            array = @[newIndexPath];
            [self.tableView insertRowsAtIndexPaths:array
                                  withRowAnimation:UITableViewRowAnimationFade];
			break;
            
		case NSFetchedResultsChangeDelete:
            array = @[indexPath];
            [self.tableView deleteRowsAtIndexPaths:array
                                  withRowAnimation:UITableViewRowAnimationLeft];
			break;
            
		case NSFetchedResultsChangeUpdate:
            [self updateEpisodeCell:(IGEpisodeCell *)[self.tableView cellForRowAtIndexPath:indexPath]
                            episode:[self.fetchedResultsController objectAtIndexPath:indexPath]];
			break;
            
        case NSFetchedResultsChangeMove:
            [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
            [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationFade];
            break;
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	[self.tableView endUpdates];
}

#pragma mark - UISearchDisplayControllerDelegate Methods

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchString:(NSString *)searchString
{
    [self filterContentForSearchText:searchString
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:[self.searchDisplayController.searchBar selectedScopeButtonIndex]]];
    return YES;
}


- (BOOL)searchDisplayController:(UISearchDisplayController *)controller shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    [self filterContentForSearchText:[self.searchDisplayController.searchBar text]
                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles] objectAtIndex:searchOption]];
    return YES;
}

#pragma mark - UILongPressGestureRecognizer Selector Method

- (IBAction)showMoreOptionsActionSheet:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:self.tableView];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:p];
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan && indexPath)
    {
        IGEpisodeCell *episodeCell = (IGEpisodeCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                      withValue:[episodeCell title]];
        
        NSString *playedItemLabel = [episode isPlayed] ? NSLocalizedString(@"MarkAsUnplayed", nil) : NSLocalizedString(@"MarkAsPlayed", nil);
        BOOL isPlayed = [episode isPlayed] ? NO : YES;
        RIButtonItem *playedItem = [RIButtonItem itemWithLabel:playedItemLabel];
        playedItem.action = ^{
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                IGEpisode *localEpisode = [episode MR_inContext:localContext];
                [localEpisode markAsPlayed:isPlayed];
                [localContext MR_saveToPersistentStoreAndWait];
            } completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                      withRowAnimation:UITableViewRowAnimationNone];
                });
            }];
        };
        
        RIButtonItem *deleteDownloadItem = nil;
        RIButtonItem *downloadItem = nil;
        if ([episode isDownloaded])
        {
            deleteDownloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"DeleteDownload", nil)];
            deleteDownloadItem.action = ^{
                [episode deleteDownloadedEpisode];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                          withRowAnimation:UITableViewRowAnimationNone];
                });
            };
        }
        else
        {
            downloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Download", nil)];
            downloadItem.action = ^{
                [self showAllowCellularDataDownloadingAlert:episodeCell];
            };
        }
        
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", nil)];
        
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                         cancelButtonItem:cancelItem
                                                    destructiveButtonItem:deleteDownloadItem
                                                         otherButtonItems:playedItem, downloadItem, nil];
        [actionSheet showInView:[self view]];
    }
}

#pragma mark - Update Episode Cell

- (void)updateEpisodeCell:(IGEpisodeCell *)episodeCell episode:(IGEpisode *)episode
{
    [episodeCell setTitle:[episode title]];
    [episodeCell setSummary:[episode summary]];
    [episodeCell setPubDate:[episode pubDate]];
    [episodeCell setTimeLeft:[episode duration]];
    [episodeCell setPlayedStatus:[episode playedStatus]];
    [episodeCell setDownloadStatus:[episode downloadStatus]];
    [episodeCell setDownloadURL:[NSURL URLWithString:[episode downloadURL]]];
    [[episodeCell downloadButton] addTarget:self
                                     action:@selector(pauseResumeDownload:)
                           forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Segue

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    if ([identifier isEqualToString:@"audioPlayerSegue"] && [sender isKindOfClass:[UITableViewCell class]])
    {
        IGEpisodeCell *cell = (IGEpisodeCell *)sender;
        IGEpisode *episode = [[self.fetchedResultsController fetchedObjects] objectAtIndex:[[cell downloadButton] tag]];
        if ([episode isDownloading])
        {
            [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForCell:cell]
                                          animated:YES];
            return NO;
        }
        
        if (![episode isDownloaded] && ![IGHTTPClient allowCellularDataStreaming])
        {
            RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"No", nil)];
            cancelItem.action = ^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForCell:cell]
                                                  animated:YES];
                });
            };
            RIButtonItem *streamItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Stream", nil)];
            streamItem.action = ^{
                [self performSegueWithIdentifier:@"audioPlayerSegue"
                                          sender:sender];
            };
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"StreamingWithCellularDataAlertTitle", nil)
                                                                message:NSLocalizedString(@"StreamingWithCellularDataAlertMessage", nil)
                                                       cancelButtonItem:cancelItem
                                                       otherButtonItems:streamItem, nil];
            [alertView show];
            
            return NO;
        }
    }
    
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"episodeShowNotesSegue"])
    {
        IGEpisode *episode = [[self.fetchedResultsController fetchedObjects] objectAtIndex:[sender tag]];
        IGEpisodeShowNotesViewController *showNotesViewController = [segue destinationViewController];
        [showNotesViewController setEpisode:episode];
    }
    else if ([[segue identifier] isEqualToString:@"audioPlayerSegue"])
    {
        UINavigationController *audioPlayerNavigationController = [segue destinationViewController];
        IGAudioPlayerViewController *audioPlayerViewController = (IGAudioPlayerViewController *)[audioPlayerNavigationController topViewController];
        
        IGEpisode *episode = nil;
        if ([sender isKindOfClass:[UITableViewCell class]])
        {
            IGEpisodeCell *cell = (IGEpisodeCell *)sender;
            episode = [[self.fetchedResultsController fetchedObjects] objectAtIndex:[[cell downloadButton] tag]];
        }
        else
        {
            // Tapped from the nav bar
            IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
            episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                               withValue:[mediaPlayer.asset title]];
            
        }
        [audioPlayerViewController loadAudioPlayerWithEpisode:episode];
    }
}

#pragma mark - Content Filtering

- (void)filterContentForSearchText:(NSString *)searchText scope:(NSString *)scope
{
    [self.filteredEpisodeArray removeAllObjects];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ || summary CONTAINS[cd] %@", searchText, searchText];
    NSArray *tempArray = [IGEpisode MR_findAllWithPredicate:predicate];
    self.filteredEpisodeArray = [NSMutableArray arrayWithArray:tempArray];
}

#pragma mark - Hide Search Bar

- (void)hideSearchBar
{
    // Check search bar is visible before continuing
    if (self.tableView.bounds.origin.y >= CGRectGetHeight(self.searchBar.bounds)) return;
    
    CGRect newBounds = [self.tableView bounds];
    newBounds.origin.y = newBounds.origin.y + CGRectGetHeight(self.searchBar.bounds);
    [self.tableView setBounds:newBounds];
}

#pragma mark - Refresh Podcast Feeds

- (void)refreshPodcastFeedWithCompletionHandler:(void (^)(BOOL newEpisodes))completion
{
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    [httpClient syncPodcastFeedWithCompletion:^(BOOL success, NSArray *feedItems, NSError *error) {
        if (!success && error)
        {
            [TDNotificationPanel showNotificationInView:self.view
                                                  title:NSLocalizedString(@"ErrorFetchingFeed", nil)
                                               subtitle:[error localizedDescription]
                                                   type:TDNotificationTypeError
                                                   mode:TDNotificationModeText
                                            dismissible:YES
                                         hideAfterDelay:4];
        }
        else
        {
            [IGEpisode importPodcastFeedItems:feedItems completion:nil];
        }
        
        [self.pullToRefreshView finishLoading];
        
        if (completion)
        {
            completion(feedItems ? YES : NO);
        }
    }];
}

#pragma mark - Episode Download Methods

- (void)showAllowCellularDataDownloadingAlert:(IGEpisodeCell *)episodeCell
{
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[episodeCell title]];
    NSURL *downloadURL = [NSURL URLWithString:[episode downloadURL]];
    
    if ([IGHTTPClient allowCellularDataDownloading])
    {
        [TestFlight passCheckpoint:[NSString stringWithFormat:@"Downloading %@", [episode title]]];
        [self startDownloadFromURL:downloadURL
                        targetPath:[episode fileURL]];
        [episodeCell setDownloadStatus:IGEpisodeDownloadStatusDownloading];
        return;
    }
    
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"No", nil)];
    RIButtonItem *downloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Download", nil)];
    downloadItem.action = ^{
        [TestFlight passCheckpoint:[NSString stringWithFormat:@"Downloading %@", [episode title]]];
        [self startDownloadFromURL:downloadURL
                        targetPath:[episode fileURL]];
        [episodeCell setDownloadStatus:IGEpisodeDownloadStatusDownloading];
    };
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DownloadingWithCellularDataAlertTitle", nil)
                                                        message:NSLocalizedString(@"DownloadingWithCellularDataAlertMessage", nil)
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:downloadItem, nil];
    [alertView show];
}

/**
 * Sets up the download operation and begins downloading the episode.
 *
 * @param downloadFromURL The URL to download the episode from.
 * @param targetPath The path to save the episode to.
 */
- (void)startDownloadFromURL:(NSURL *)downloadURL
                  targetPath:(NSURL *)targetPath
{
    IGHTTPClient *sharedClient = [IGHTTPClient sharedClient];
    [sharedClient downloadEpisodeWithURL:downloadURL targetPath:targetPath completion:^(BOOL success, NSError *error) {
        if (!success && error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TDNotificationPanel showNotificationInView:self.view
                                                      title:NSLocalizedString(@"FailedToDownloadEpisode", @"text label for failed to download episode")
                                                   subtitle:[error localizedDescription]
                                                       type:TDNotificationTypeError
                                                       mode:TDNotificationModeText
                                                dismissible:YES
                                             hideAfterDelay:4];
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}

- (void)pauseResumeDownload:(UIButton *)sender
{
    IGEpisodeCell *episodeCell = (IGEpisodeCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[sender tag] inSection:0]];
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[episodeCell title]];
    IGHTTPClient *sharedClient = [IGHTTPClient sharedClient];
    AFDownloadRequestOperation *requestOperation = [sharedClient requestOperationForURL:[NSURL URLWithString:[episode downloadURL]]];
    if (!requestOperation)
    {
        return;
    }
    
    requestOperation.isPaused ? [requestOperation resume] : [requestOperation pause];
    [episodeCell setDownloadStatus:IGEpisodeDownloadStatusDownloading];
}

#pragma mark - SSPullToRefreshViewDelegate

- (BOOL)pullToRefreshViewShouldStartLoading:(SSPullToRefreshView *)view
{
    return YES;
}

- (void)pullToRefreshViewDidStartLoading:(SSPullToRefreshView *)view
{
    [self refreshPodcastFeedWithCompletionHandler:nil];
}

@end
