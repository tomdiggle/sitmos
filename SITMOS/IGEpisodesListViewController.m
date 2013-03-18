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

#import "IGEpisodesListViewController.h"
#import "IGEpisodeTableViewCell.h"
#import "IGEpisode.h"
#import "IGAudioPlayerViewController.h"
#import "IGEpisodeMoreInfoViewController.h"
#import "IGSettingsViewController.h"
#import "EGORefreshTableHeaderView.h"
#import "UIViewController+MJPopupViewController.h"
#import "RIButtonItem.h"
#import "UIActionSheet+Blocks.h"
#import "UIAlertView+Blocks.h"
#import "IGHTTPClient.h"
#import "AFHTTPRequestOperation.h"
#import "UIApplication+LocalNotificationHelper.h"
#import "UIViewController+NowPlayingButton.h"
#import "TDNotificationPanel.h"
#import "IGMediaPlayerAsset.h"
#import "IGEpisodeDateAndDurationLabel.h"

@interface IGEpisodesListViewController () <NSFetchedResultsControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, IGEpisodeTableViewCellDelegate, EGORefreshTableHeaderDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) EGORefreshTableHeaderView *refreshHeaderView;
@property (strong, nonatomic) IGEpisodeMoreInfoViewController *episodeMoreInfoViewController;
@property (strong, nonatomic) NSMutableArray *filteredEpisodeArray;
@property BOOL reloading;

@end

@implementation IGEpisodesListViewController

#pragma mark - View lifecycle

- (void)viewWillLayoutSubviews
{
    if (!_refreshHeaderView)
    {
        EGORefreshTableHeaderView *refreshView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - _tableView.bounds.size.height, self.view.frame.size.width, _tableView.bounds.size.height)];
        [refreshView setDelegate:self];
        [_tableView addSubview:refreshView];
        _refreshHeaderView = refreshView;
    }
    
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
    
    _fetchedResultsController = [IGEpisode MR_fetchAllSortedBy:@"pubDate"
                                                     ascending:NO
                                                 withPredicate:nil
                                                       groupBy:nil
                                                      delegate:self];
    
    [self reloadTableViewDataSource];
    
    [self invokeAllDownloadRequests];
    
    // Notifications below are used to check if the now playing button should still be displayed
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(displayNowPlayingButton)
                                                 name:IGMediaPlayerPlaybackEndedNotification
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if ([_tableView indexPathForSelectedRow])
    {
        [_tableView reloadRowsAtIndexPaths:@[ [_tableView indexPathForSelectedRow] ]
                          withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self displayNowPlayingButton];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - IBAction

- (IBAction)settingsButtonTapped:(id)sender
{
    IGSettingsViewController *settingsViewController = [[IGSettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    [[self navigationController] presentViewController:settingsNavigationController
                                              animated:YES
                                            completion:nil];
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
        return [_filteredEpisodeArray count];
    }
    
    id <NSFetchedResultsSectionInfo> sectionInfo = nil;
    sectionInfo = [[_fetchedResultsController sections] objectAtIndex:section];
	return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    IGEpisodeTableViewCell *episodeCell = (IGEpisodeTableViewCell *)[_tableView dequeueReusableCellWithIdentifier:@"episodeCellIdentifier"];
    IGEpisode *episode = tableView == self.searchDisplayController.searchResultsTableView ? [_filteredEpisodeArray objectAtIndex:indexPath.row] : [_fetchedResultsController objectAtIndexPath:indexPath];
    
    [self updateEpisodeCell:episodeCell
                    episode:episode];
    
    UIColor *color = [episode isPlayed] ? kRGBA(179, 179, 179, 1) : kRGBA(41, 41, 41, 1);
    [[episodeCell episodeTitleLabel] setTextColor:color];
    [[episodeCell episodeTitleLabel] setHighlightedTextColor:color];
    
    color = [indexPath row] % 2 ? kRGBA(245, 245, 245, 1) : kRGBA(240, 240, 240, 1);
    [[episodeCell contentView] setBackgroundColor:color];
    
    UIView *selectedBackgroundView = [[UIView alloc] init];
    [selectedBackgroundView setBackgroundColor:kRGBA(217, 236, 245, 1)];
    [episodeCell setSelectedBackgroundView:selectedBackgroundView];
    
    [episodeCell setAccessibilityTraits:UIAccessibilityTraitStartsMediaSession];
    
    return episodeCell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    IGEpisode *episode = tableView == self.searchDisplayController.searchResultsTableView ? [_filteredEpisodeArray objectAtIndex:indexPath.row] : [_fetchedResultsController objectAtIndexPath:indexPath];
    
    [self playEpisode:episode];
}

#pragma mark - NSFetchResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
	[_tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    NSArray *array = nil;
	switch (type)
    {
		case NSFetchedResultsChangeInsert:
            array = @[newIndexPath];
            [_tableView insertRowsAtIndexPaths:array
                              withRowAnimation:UITableViewRowAnimationFade];
			break;
            
		case NSFetchedResultsChangeDelete:
            array = @[indexPath];
            [_tableView deleteRowsAtIndexPaths:array
                              withRowAnimation:UITableViewRowAnimationLeft];
			break;
            
		case NSFetchedResultsChangeUpdate:
            [self updateEpisodeCell:(IGEpisodeTableViewCell *)[_tableView cellForRowAtIndexPath:indexPath]
                            episode:[_fetchedResultsController objectAtIndexPath:indexPath]];
			break;
            
        case NSFetchedResultsChangeMove:
            [_tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
            [_tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
            break;
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	[_tableView endUpdates];
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
// TODO Refactor
- (IBAction)displayMoreOptions:(UILongPressGestureRecognizer *)gestureRecognizer
{
    CGPoint p = [gestureRecognizer locationInView:_tableView];
    NSIndexPath *indexPath = [_tableView indexPathForRowAtPoint:p];
    
    if ([gestureRecognizer state] == UIGestureRecognizerStateBegan && indexPath)
    {
        // Get the episode the user wants to delete
        IGEpisodeTableViewCell *episodeCell = (IGEpisodeTableViewCell*)[_tableView cellForRowAtIndexPath:indexPath];
        IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                      withValue:[[episodeCell episodeTitleLabel] text]];
        
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", @"text label for cancel")];
        
        NSString *downloadLabel = [episode isDownloaded] ? NSLocalizedString(@"DeleteDownload", @"text label for delete download") : NSLocalizedString(@"Download", @"text label for download");
        RIButtonItem *downloadItem = [RIButtonItem itemWithLabel:downloadLabel];
        downloadItem.action = ^{
            if ([episode isDownloaded])
            {
                [episode deleteDownloadedEpisode];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                      withRowAnimation:UITableViewRowAnimationNone];
                });
            }
            else
            {
                [self igEpisodeTableViewCell:episodeCell
                 downloadEpisodeButtonTapped:nil];
            }
        };
        
        NSString *playedLabel = [episode isPlayed] ? NSLocalizedString(@"MarkAsUnplayed", "text label for mark as unplayed") : NSLocalizedString(@"MarkAsPlayed", "text label for mark as played");
        RIButtonItem *playedItem = [RIButtonItem itemWithLabel:playedLabel];
        playedItem.action = ^{
            if ([episode isPlayed])
            {
                // Mark episode as unplayed
                [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                    IGEpisode *localEpisode = [episode MR_inContext:localContext];
                    [localEpisode markAsPlayed:NO];
                    [localContext MR_saveToPersistentStoreAndWait];
                } completion:^(BOOL success, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                          withRowAnimation:UITableViewRowAnimationNone];
                    });
                }];
            }
            else
            {
                // Mark episode as played
                [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                    IGEpisode *localEpisode = [episode MR_inContext:localContext];
                    [localEpisode markAsPlayed:YES];
                    [localContext MR_saveToPersistentStoreAndWait];
                } completion:^(BOOL success, NSError *error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                          withRowAnimation:UITableViewRowAnimationNone];
                    });
                }];
            }
        };
        
        UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                         cancelButtonItem:cancelItem
                                                    destructiveButtonItem:nil
                                                         otherButtonItems:playedItem, downloadItem, nil];
        [actionSheet showInView:[self view]];
    }
}

#pragma mark - Update Episode Table View Cell

- (void)updateEpisodeCell:(IGEpisodeTableViewCell *)episodeCell episode:(IGEpisode *)episode
{
    [episodeCell setDelegate:self];
    [[episodeCell episodeTitleLabel] setText:[episode title]];
    NSString *episodeDateDuration = [NSString stringWithFormat:@"%@ - %@", [NSDate stringFromDate:[episode pubDate] withFormat:@"dd MMM yyyy"], [episode duration]];
    [[episodeCell episodeDateAndDurationLabel] setText:episodeDateDuration];
    [episodeCell setDownloadURL:[NSURL URLWithString:[episode downloadURL]]];
    [episodeCell setPlayedStatus:[episode playedStatus]];
    [episodeCell setDownloadStatus:[episode downloadStatus]];
}

#pragma mark - Content Filtering

- (void)filterContentForSearchText:(NSString *)searchText scope:(NSString *)scope
{
    [_filteredEpisodeArray removeAllObjects];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title CONTAINS[cd] %@ || summary CONTAINS[cd] %@", searchText, searchText];
    NSArray *tempArray = [IGEpisode MR_findAllWithPredicate:predicate];
    _filteredEpisodeArray = [NSMutableArray arrayWithArray:tempArray];
}

#pragma mark - Hide Search Bar

- (void)hideSearchBar
{
    // Check search bar is visible before continuing
    if (_tableView.bounds.origin.y >= _searchBar.bounds.size.height) return;
    
    CGRect newBounds = [_tableView bounds];
    newBounds.origin.y = newBounds.origin.y + _searchBar.bounds.size.height;
    [_tableView setBounds:newBounds];
}

#pragma mark - Display Now Playing Button

- (void)displayNowPlayingButton
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    [self showNowPlayingButon:([mediaPlayer asset] != nil)];
}

#pragma mark - Play Episode

- (void)playEpisode:(IGEpisode *)episode
{
    if ([episode isAudio])
    {
        if ([episode isDownloaded])
        {
            [self playAudioEpisode:episode];
        }
        else
        {
            [self canStreamEpisode:episode];
        }
    }
}

- (void)playAudioEpisode:(IGEpisode *)episode
{
    IGAudioPlayerViewController *audioPlayer = [[self storyboard] instantiateViewControllerWithIdentifier:@"IGAudioPlayerViewController"];
    [audioPlayer setTitle:[episode title]];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav-back-arrow"]
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];
    
    [[self navigationController] pushViewController:audioPlayer
                                           animated:YES];
    
    dispatch_queue_t startPlaybackQueue = dispatch_queue_create("com.IdleGeniusSoftware.SITMOS.startPlaybackQueue", NULL);
	dispatch_async(startPlaybackQueue, ^{
        NSURL *contentURL = [episode isDownloaded] ? [episode fileURL] : [NSURL URLWithString:[episode downloadURL]];
        IGMediaPlayerAsset *asset = [[IGMediaPlayerAsset alloc] init];
        [asset setContentURL:contentURL];
        [asset setTitle:[episode title]];
        
        IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
        [mediaPlayer setStartFromTime:[[episode progress] floatValue]];
        [mediaPlayer startWithAsset:asset];
        
        [mediaPlayer setPausedBlock:^(Float64 currentTime) {
            // Save current time so playback can resume where left off
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                IGEpisode *localEpisode = [episode MR_inContext:localContext];
                [localEpisode setProgress:@(currentTime)];
            }];
        }];
        
        [mediaPlayer setStoppedBlock:^(Float64 currentTime, BOOL playbackEnded) {
            // Delete episode?
            NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
            if ([userDefaults boolForKey:IGSettingEpisodesDelete])
            {
                [episode deleteDownloadedEpisode];
            }
            
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                IGEpisode *localEpisode = [episode MR_inContext:localContext];
                BOOL markAsPlayed = [localEpisode isPlayed];
                Float64 progress = currentTime;
                if (playbackEnded)
                {
                    markAsPlayed = YES;
                    progress = 0;
                }
                [localEpisode markAsPlayed:markAsPlayed];
                [localEpisode setProgress:@(progress)];
            }];
        }];
    });
}

/**
 * Checks to see if streaming is available with cellular data.
 */
- (void)canStreamEpisode:(IGEpisode *)episode
{
    BOOL allowCellularDataStreaming = [[NSUserDefaults standardUserDefaults] boolForKey:IGSettingCellularDataStreaming];
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    AFNetworkReachabilityStatus networkReachabilityStatus = [httpClient networkReachabilityStatus];
    if (!allowCellularDataStreaming && networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN)
    {
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", "text label for cancel")];
        cancelItem.action = ^{
            if ([_tableView indexPathForSelectedRow])
            {
                [_tableView reloadRowsAtIndexPaths:@[ [_tableView indexPathForSelectedRow] ]
                                  withRowAnimation:UITableViewRowAnimationFade];
            }
        };
        RIButtonItem *streamItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Stream", @"text label for stream")];
        streamItem.action = ^{
            [self playAudioEpisode:episode];
        };
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"StreamingWithCellularDataTitle", @"text label for streaming with cellular data title")
                                                            message:NSLocalizedString(@"StreamingWithCellularDataMessage", @"text label for streaming with cellular data message")
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:streamItem, nil];
        [alertView show];
    }
    else
    {
        [self playAudioEpisode:episode];
    }
}

#pragma mark - Refresh Feed

- (void)refreshFeed
{
    if (_reloading) return;
    
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    [httpClient syncPodcastFeedWithSuccess:^{
        [self doneLoadingTableViewData];
    } failure:^(NSError *error) {
        [self doneLoadingTableViewData];
        [TDNotificationPanel showNotificationPanelInView:self.view
                                                    type:TDNotificationTypeError
                                                   title:NSLocalizedString(@"ErrorFetchingFeed", @"text label for error fetching feed")
                                          hideAfterDelay:5];
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
	[_refreshHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:_tableView];
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
    [sharedClient downloadEpisodeWithURL:downloadFromURL targetPath:targetPath success:^(AFHTTPRequestOperation *operation, id responseObject) {
        dispatch_async(dispatch_get_main_queue(), ^{
            // Reload the table view's data if a download succeeds
            [_tableView reloadData];
        });
        if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
        {
            IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"downloadURL"
                                                          withValue:[[operation request] URL]];
            // If app is in background state display a local notification alerting the user that the download has finished.
            NSDictionary *parameters = @{@"alertBody" : [NSString stringWithFormat:NSLocalizedString(@"SuccessfullyDownloadedEpisode", @"text label for successfully downloaded episode"), [episode title]], @"soundName" : UILocalNotificationDefaultSoundName};
            [UIApplication presentLocalNotificationNowWithParameters:parameters];
        }
     } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
         dispatch_async(dispatch_get_main_queue(), ^{
             [self downloadOperation:operation
                     failedWithError:error];
         
             // Reload the table view's data if a download fails
             [_tableView reloadData];
         });
     }];
}
 
// TODO handle other types of errors
// More than likely will need refactoring
- (void)downloadOperation:(AFHTTPRequestOperation *)operation
          failedWithError:(NSError *)error
{
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"downloadURL"
                                                  withValue:[[operation request] URL]];

    if ([error code] == IGHTTPClientNetworkErrorCellularDataDownloadingNotAllowed)
    {
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"No", "text label for no")];
        RIButtonItem *downloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Yes", @"text label for yes")];
        downloadItem.action = ^{
            [[NSUserDefaults standardUserDefaults] setBool:YES
                                                    forKey:IGSettingCellularDataDownloading];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [self startDownloadFromURL:[NSURL URLWithString:[episode downloadURL]]
                            targetPath:[episode fileURL]];
        };

        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DownloadingWithCellularDataTitle", @"text label for downloading with cellular data title")
                                                            message:NSLocalizedString(@"DownloadingWithCellularDataMessage", @"text label for downloading with cellular data message")
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:downloadItem, nil];
        [alertView show];
    }
    else
    {
        [TDNotificationPanel showNotificationPanelInView:self.view
                                                    type:TDNotificationTypeError
                                                   title:[NSString stringWithFormat:NSLocalizedString(@"FailedToDownloadEpisode", @"text label for failed to download episode"), [episode title]]
                                          hideAfterDelay:5];
    }
 
    if ([[UIApplication sharedApplication] applicationState] == UIApplicationStateBackground)
    {
        NSDictionary *parameters = @{@"alertBody" : [NSString stringWithFormat:NSLocalizedString(@"FailedToDownloadEpisode", @"text label for failed to download episode"), [episode title]], @"soundName" : UILocalNotificationDefaultSoundName};
        [UIApplication presentLocalNotificationNowWithParameters:parameters];
    }
}

- (void)invokeAllDownloadRequests
{
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    NSArray *currentDownloadRequests = [httpClient currentDownloadRequests];
    [currentDownloadRequests enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [self startDownloadFromURL:[obj objectAtIndex:0] targetPath:[obj objectAtIndex:1]];
    }];
}

#pragma mark - IGEpisodeTableViewCellDelegate Methods

/**
 * Invoked when the more info icon is tapped. A popup view is displayed with more information about the episode.
 */
- (void)igEpisodeTableViewCell:(IGEpisodeTableViewCell *)episodeTableViewCell
displayMoreInfoAboutEpisodeWithTitle:(NSString *)title
{
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:title];
    
    _episodeMoreInfoViewController = [[self storyboard] instantiateViewControllerWithIdentifier:@"IGEpisodeMoreInfoViewController"];
    [_episodeMoreInfoViewController setEpisode:episode];
    [self presentPopupViewController:_episodeMoreInfoViewController
                       animationType:MJPopupViewAnimationFade];
}

/**
 * Invoked when the download button in the table view cell is tapped.
 */
- (void)igEpisodeTableViewCell:(IGEpisodeTableViewCell *)episodeTableViewCell
   downloadEpisodeButtonTapped:(UIButton *)button
{    
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[[episodeTableViewCell episodeTitleLabel] text]];
    NSURL *downloadFromURL = [NSURL URLWithString:[episode downloadURL]];
    
    IGHTTPClient *sharedClient = [IGHTTPClient sharedClient];
    AFHTTPRequestOperation *requestOperation = [sharedClient requestOperationForURL:downloadFromURL];
     
    if (!requestOperation)
    {
        [self startDownloadFromURL:downloadFromURL
                        targetPath:[episode fileURL]];
    }
    else if ([requestOperation isPaused])
    {
        [requestOperation resume];
    }
    else
    {
        [requestOperation pause];
    }
    
    [episodeTableViewCell setDownloadStatus:IGEpisodeDownloadStatusDownloading];
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
