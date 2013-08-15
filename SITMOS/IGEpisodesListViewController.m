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
#import "IGMediaPlayerViewController.h"
#import "IGEpisodeShowNotesViewController.h"
#import "IGSettingsViewController.h"
#import "IGDefines.h"
#import "IGMediaPlayerAsset.h"
#import "IGMediaPlayer.h"
#import "EGORefreshTableHeaderView.h"
#import "RIButtonItem.h"
#import "UIActionSheet+Blocks.h"
#import "UIAlertView+Blocks.h"
#import "IGHTTPClient.h"
#import "AFDownloadRequestOperation.h"
#import "UIViewController+MediaPlayer.h"
#import "TDNotificationPanel.h"
#import "CoreData+MagicalRecord.h"

@interface IGEpisodesListViewController () <NSFetchedResultsControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, EGORefreshTableHeaderDelegate>

@property (nonatomic, weak) IBOutlet UITableView *tableView;
@property (nonatomic, weak) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) EGORefreshTableHeaderView *refreshHeaderView;
@property (nonatomic, strong) NSMutableArray *filteredEpisodeArray;
@property BOOL reloading;

@end

@implementation IGEpisodesListViewController

#pragma mark - View lifecycle

- (void)viewWillLayoutSubviews
{
    /*if (!_refreshHeaderView)
    {
        EGORefreshTableHeaderView *refreshView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, self.view.frame.size.width, self.tableView.bounds.size.height)];
        [refreshView setDelegate:self];
        [self.tableView addSubview:refreshView];
        _refreshHeaderView = refreshView;
    }*/
    
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
    
    [self setTitle:@"SITMOS"];
    
    [self.tableView registerClass:[IGEpisodeCell class]
       forCellReuseIdentifier:@"episodeCell"];
    [[self.searchDisplayController searchResultsTableView] setRowHeight:self.tableView.rowHeight];
    
    self.fetchedResultsController = [IGEpisode MR_fetchAllSortedBy:@"pubDate"
                                                         ascending:NO
                                                     withPredicate:nil
                                                           groupBy:nil
                                                          delegate:self];
    
//    [self reloadTableViewDataSource];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ([self.tableView indexPathForSelectedRow])
    {
        [self.tableView reloadRowsAtIndexPaths:@[[self.tableView indexPathForSelectedRow]]
                          withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    if ([mediaPlayer asset])
    {
        [self displayNowPlayingButon];
    }
    else
    {
        [self hideNowPlayingButton:YES];
    }
}

#pragma mark - Show Settings

- (IBAction)showSettings:(id)sender
{
    IGSettingsViewController *settingsViewController = [[IGSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    [[self navigationController] presentViewController:settingsNavigationController
                                              animated:YES
                                            completion:nil];
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
    
    [[episodeCell moreInfoButton] setTag:indexPath.row];
    [[episodeCell downloadButton] setTag:indexPath.row];
    
    UIView *selectedBackgroundView = [[UIView alloc] init];
    [selectedBackgroundView setBackgroundColor:kRGBA(217, 236, 245, 1)];
    [episodeCell setSelectedBackgroundView:selectedBackgroundView];
    
    [episodeCell setAccessibilityTraits:UIAccessibilityTraitStartsMediaSession];
    
    return episodeCell;
}

#pragma mark - UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Build media player asset
    IGEpisodeCell *cell = (IGEpisodeCell *)[tableView cellForRowAtIndexPath:indexPath];
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[cell title]];
    IGMediaPlayerAsset *asset = [[IGMediaPlayerAsset alloc] init];
    [asset setTitle:[episode title]];
    NSURL *contentURL = [episode isDownloaded] ? [episode fileURL] : [NSURL URLWithString:[episode downloadURL]];
    [asset setContentURL:contentURL];
    [asset setAudio:[episode isAudio]];
    
    [self showMediaPlayerWithAsset:asset];
    
    [tableView deselectRowAtIndexPath:indexPath
                             animated:YES];
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

#pragma mark - UIScrollViewDelegate Methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[_refreshHeaderView egoRefreshScrollViewDidScroll:scrollView];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	[_refreshHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
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
        
        NSString *playedItemLabel = [episode isPlayed] ? NSLocalizedString(@"MarkAsUnplayed", "text label for mark as unplayed") : NSLocalizedString(@"MarkAsPlayed", "text label for mark as played");
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
            deleteDownloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"DeleteDownload", @"text label for delete download")];
            deleteDownloadItem.action = ^{
                [episode deleteDownloadedEpisode];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                      withRowAnimation:UITableViewRowAnimationNone];
                });
            };
        }
        else if ([episode isAudio])
        {
            // Only Audio episodes are downloadable
            downloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Download", @"text label for download")];
            downloadItem.action = ^{
                if ([episode isDownloaded])
                {
                    [episode deleteDownloadedEpisode];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.tableView reloadRowsAtIndexPaths:@[indexPath]
                                          withRowAnimation:UITableViewRowAnimationNone];
                    });
                }
                else
                {
//                    [self startDownloadFromURL:[NSURL URLWithString:[episode downloadURL]]
//                                    targetPath:[episode fileURL]];
                }
            };
        }
        
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", @"text label for cancel")];
        
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
    [[episodeCell moreInfoButton] addTarget:self
                                     action:@selector(showMoreInfoAboutEpisode:)
                           forControlEvents:UIControlEventTouchUpInside];
    [[episodeCell downloadButton] addTarget:self
                                     action:@selector(beginDownloadingEpisode:)
                           forControlEvents:UIControlEventTouchUpInside];
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

#pragma mark - Refresh Feed

- (void)refreshFeed
{
    if (_reloading) return;
    
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    [httpClient syncPodcastFeedsWithCompletion:^(BOOL success, NSError *error) {
       [self doneLoadingTableViewData];
        if (!success && error) {
            [TDNotificationPanel showNotificationInView:self.view
                                                  title:NSLocalizedString(@"ErrorFetchingFeed", @"text label for error fetching feed")
                                               subtitle:nil
                                                   type:TDNotificationTypeError
                                                   mode:TDNotificationModeText
                                            dismissable:YES
                                         hideAfterDelay:4];
        }
    }];
}

- (void)reloadTableViewDataSource
{
    [self refreshFeed];
	_reloading = YES;
}

- (void)doneLoadingTableViewData
{
	_reloading = NO;
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self.tableView];
    [self hideSearchBar];
}

#pragma mark - Episode Download Methods

/**
 * Sets up the download operation and begins downloading the episode.
 *
 * @param downloadFromURL The URL to download the episode from.
 * @param targetPath The path to save the episode to.
 */
- (void)startDownloadFromURL:(NSURL *)downloadFromURL
                  targetPath:(NSURL *)targetPath
{
    IGHTTPClient *sharedClient = [IGHTTPClient sharedClient];
    [sharedClient downloadEpisodeWithURL:downloadFromURL targetPath:targetPath completion:^(BOOL success, NSError *error) {
        if (!success && error)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [TDNotificationPanel showNotificationInView:self.view
                                                      title:NSLocalizedString(@"FailedToDownloadEpisode", @"text label for failed to download episode")
                                                   subtitle:nil
                                                       type:TDNotificationTypeError
                                                       mode:TDNotificationModeText
                                                dismissable:YES
                                             hideAfterDelay:4];
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
        });
    }];
}

#pragma mark - IGEpisodeTableViewCellDelegate Methods

/**
 * Invoked when the more info icon is tapped.
 */
- (void)showMoreInfoAboutEpisode:(UIButton *)sender
{
    IGEpisodeCell *episodeCell = (IGEpisodeCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[sender tag] inSection:0]];
    
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[episodeCell title]];
    IGEpisodeShowNotesViewController *moreInfoViewController = [[IGEpisodeShowNotesViewController alloc] initWithEpisode:episode];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Episodes", @"text label for episodes")
                                                                             style:UIBarButtonItemStylePlain
                                                                            target:nil
                                                                            action:nil];
    [[self navigationController] pushViewController:moreInfoViewController
                                           animated:YES];
}

/**
 * Invoked when the download button in the table view cell is tapped.
 */
- (void)beginDownloadingEpisode:(UIButton *)sender
{
    IGEpisodeCell *episodeCell = (IGEpisodeCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:[sender tag] inSection:0]];
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[episodeCell title]];
    NSURL *downloadFromURL = [NSURL URLWithString:[episode downloadURL]];
    
    IGHTTPClient *sharedClient = [IGHTTPClient sharedClient];
    AFDownloadRequestOperation *requestOperation = [sharedClient requestOperationForURL:downloadFromURL];
    if (!requestOperation)
    {
        if (![IGHTTPClient allowCellularDataDownloading])
        {
            RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"No", "text label for no")];
            cancelItem.action = ^{
                [episodeCell setDownloadStatus:IGEpisodeDownloadStatusNotDownloading];
            };
            RIButtonItem *downloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Yes", @"text label for yes")];
            downloadItem.action = ^{
                [self startDownloadFromURL:downloadFromURL
                                targetPath:[episode fileURL]];
                
                [episodeCell setDownloadStatus:IGEpisodeDownloadStatusDownloading];
            };
            
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DownloadingWithCellularDataTitle", @"text label for downloading with cellular data title")
                                                                message:NSLocalizedString(@"DownloadingWithCellularDataMessage", @"text label for downloading with cellular data message")
                                                       cancelButtonItem:cancelItem
                                                       otherButtonItems:downloadItem, nil];
            [alertView show];
        }
        else
        {
            [self startDownloadFromURL:downloadFromURL
                            targetPath:[episode fileURL]];
        }
    }
    else if ([requestOperation isPaused])
    {
        [requestOperation resume];
    }
    else
    {
        [requestOperation pause];
    }
    
    [episodeCell setDownloadStatus:IGEpisodeDownloadStatusDownloading];
}

#pragma mark - EGORefreshTableHeaderDelegate Methods

- (void)egoRefreshTableHeaderDidTriggerRefresh:(EGORefreshTableHeaderView *)view
{
	[self reloadTableViewDataSource];
}

- (BOOL)egoRefreshTableHeaderDataSourceIsLoading:(EGORefreshTableHeaderView *)view
{
	return _reloading;
}

@end
