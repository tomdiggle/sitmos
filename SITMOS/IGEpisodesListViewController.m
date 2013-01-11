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
#import "IGEpisodeDownloadOperation.h"
#import "IGEpisodeMoreInfoViewController.h"
#import "IGSettingsViewController.h"
#import "EGORefreshTableHeaderView.h"
#import "UIViewController+MJPopupViewController.h"
#import "MBProgressHUD.h"
#import "RIButtonItem.h"
#import "UIActionSheet+Blocks.h"
#import "UIAlertView+Blocks.h"
#import "DACircularProgressView.h"
#import "Reachability.h"
#import "IGHTTPClient.h"

@interface IGEpisodesListViewController () <NSFetchedResultsControllerDelegate, UISearchBarDelegate, UISearchDisplayDelegate, IGEpisodeMoreInfoViewControllerDelegate, IGEpisodeTableViewCellDelegate, EGORefreshTableHeaderDelegate>

@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;
@property (strong, nonatomic) EGORefreshTableHeaderView *refreshHeaderView;
@property (strong, nonatomic) IGEpisodeMoreInfoViewController *episodeMoreInfoViewController;
@property (strong, nonatomic) NSOperationQueue *downloadEpisodeQueue;
@property (strong, nonatomic) UILongPressGestureRecognizer *longPressRecognizer;
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
    
#ifdef TESTING
    // During testing mode a feedback button will be displayed at the top left of the nav bar
    UIBarButtonItem *feedbackButton = [[UIBarButtonItem alloc] initWithTitle:@"Feedback"
                                                                       style:UIBarButtonItemStyleBordered
                                                                      target:self
                                                                      action:@selector(launchFeedback)];
    [[self navigationItem] setLeftBarButtonItem:feedbackButton];
#endif
    
    _fetchedResultsController = [IGEpisode MR_fetchAllSortedBy:@"pubDate"
                                                     ascending:NO
                                                 withPredicate:nil
                                                       groupBy:nil
                                                      delegate:self];
    
    [self refreshFeed];
    
    _longPressRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self
                                                                         action:@selector(longPress:)];
    [_longPressRecognizer setMinimumPressDuration:1.0];
    [_tableView addGestureRecognizer:_longPressRecognizer];
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
    [[episodeCell downloadProgressView] setBackgroundColor:color];
    
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

- (void)longPress:(UILongPressGestureRecognizer *)gestureRecognizer
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
        
        NSString *downloadLabel = [episode isCompletelyDownloaded] ? NSLocalizedString(@"DeleteDownload", @"text label for delete download") : NSLocalizedString(@"Download", @"text label for download");
        RIButtonItem *downloadItem = [RIButtonItem itemWithLabel:downloadLabel];
        downloadItem.action = ^{
            if ([episode isCompletelyDownloaded])
            {
                [episode deleteDownloadedEpisode];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                      withRowAnimation:UITableViewRowAnimationNone];
                });
            }
            else
            {
                [self addEpisodeToDownloadQueue:episode];
            }
        };
        
        NSString *playedLabel = [episode isPlayed] ? NSLocalizedString(@"Mark as unplayed", "text label for mark as unplayed") : NSLocalizedString(@"Mark as played", "text label for mark as played");
        RIButtonItem *playedItem = [RIButtonItem itemWithLabel:playedLabel];
        playedItem.action = ^{
            if ([episode isPlayed])
            {
                // Mark episode as unplayed
                [MagicalRecord saveInBackgroundWithBlock:^(NSManagedObjectContext *localContext) {
                    IGEpisode *localEpisode = (IGEpisode *)[[NSManagedObjectContext MR_defaultContext] objectWithID:[episode objectID]];
                    [localEpisode markAsPlayed:NO];
                    [localContext MR_saveNestedContexts];
                } completion:^{
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [_tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                          withRowAnimation:UITableViewRowAnimationNone];
                    });
                }];
            }
            else
            {
                // Mark episode as played
                [MagicalRecord saveInBackgroundWithBlock:^(NSManagedObjectContext *localContext) {
                    IGEpisode *localEpisode = (IGEpisode *)[[NSManagedObjectContext MR_defaultContext] objectWithID:[episode objectID]];
                    [localEpisode markAsPlayed:YES];
                    [localContext MR_saveNestedContexts];
                } completion:^{
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
    [episodeCell setPlayedStatus:[episode playedStatus]];
    [episodeCell setDownloadStatus:[episode downloadStatus]];
//        [episodeCell setDownloadStatus:IGEpisodeDownloadStatusDownloadingPaused];
//        CGFloat progress = (float)[episode downloadedFileSize] / [[episode fileSize] floatValue];
//        [[episodeCell downloadProgressView] setProgress:progress];
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

#pragma mark - Play Episode

- (void)playEpisode:(IGEpisode *)episode
{
    if ([episode isAudio])
    {
        if (![episode isCompletelyDownloaded])
        {
            dispatch_queue_t canStreamEpisodeQueue = dispatch_queue_create("com.IdleGeniusSoftware.SITMOS.canStreamEpisodeQueue", NULL);
            dispatch_async(canStreamEpisodeQueue, ^{
                [self canStreamEpisode:episode];
            });
        }
        else
        {
            [self playAudioEpisode:episode];
        }
    }
}

- (void)playAudioEpisode:(IGEpisode *)episode
{
    dispatch_queue_t startPlaybackQueue = dispatch_queue_create("com.IdleGeniusSoftware.SITMOS.startPlaybackQueue", NULL);
	dispatch_async(startPlaybackQueue, ^{
        IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
        [mediaPlayer setStartFromTime:[[episode progress] floatValue]];
        NSURL *contentURL = [episode isCompletelyDownloaded] ? [episode fileURL] : [NSURL URLWithString:[episode downloadURL]];
        [mediaPlayer startWithContentURL:contentURL];
        
        [mediaPlayer setPausedBlock:^(Float64 currentTime) {
            // Save current time so playback can resume where left off
            [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
                IGEpisode *localEpisode = (IGEpisode *)[[NSManagedObjectContext MR_defaultContext] objectWithID:[episode objectID]];
                [localEpisode setProgress:@(currentTime)];
                [localContext MR_saveNestedContexts];
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
                IGEpisode *localEpisode = (IGEpisode *)[[NSManagedObjectContext MR_defaultContext] objectWithID:[episode objectID]];
                BOOL markAsPlayed = [localEpisode isPlayed];
                Float64 progress = currentTime;
                if (playbackEnded)
                {
                    markAsPlayed = YES;
                    progress = 0;
                }
                [localEpisode markAsPlayed:markAsPlayed];
                [localEpisode setProgress:@(progress)];
                [localContext MR_saveNestedContexts];
            }];
        }];
    });
    
    IGAudioPlayerViewController *audioPlayer = [[self storyboard] instantiateViewControllerWithIdentifier:@"IGAudioPlayerViewController"];
    [audioPlayer setTitle:[episode title]];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav-back-arrow"]
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];
    
    [[self navigationController] pushViewController:audioPlayer
                                           animated:YES];
}

/**
 * Checks to see if streaming is available with cellular data.
 */
- (void)canStreamEpisode:(IGEpisode *)episode
{
    NSURL *url = [NSURL URLWithString:[episode downloadURL]];
    NSString *hostname = [NSString stringWithFormat:@"%@", [url host]];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    Reachability *reach = [Reachability reachabilityWithHostname:hostname];
    reach.reachableOnWWAN = [userDefaults boolForKey:IGSettingCellularDataStreaming];
    
    if (reach.isReachable)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self playAudioEpisode:episode];
        });
    }
    else
    {
        dispatch_async(dispatch_get_main_queue(), ^{
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
        });
    }
}

#pragma mark - Download Episode

/**
 * Invoked when pausing a download. Removes the episode from the download queue by calling the cancel method on the object.
 */
- (void)removeEpisodeFromDownloadQueue:(IGEpisode *)episode
{
    NSArray *activeOperations = [_downloadEpisodeQueue operations];
    [activeOperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[[obj episode] title] isEqualToString:[episode title]])
        {
            [obj cancel];
            *stop = YES;
        }
    }];
}

- (BOOL)episodeIsDownloading:(IGEpisode *)episode
{
    NSArray *activeOperations = [_downloadEpisodeQueue operations];
    __block BOOL downloadingEpisode = NO;
    [activeOperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[[obj episode] title] isEqualToString:[episode title]])
        {
            downloadingEpisode = YES;
            *stop = YES;
        }
    }];
    
    return downloadingEpisode;
}

- (void)addEpisodeToDownloadQueue:(IGEpisode *)episode
{
    if ([episode isCompletelyDownloaded]) return;

    if (!_downloadEpisodeQueue)
    {
        _downloadEpisodeQueue = [[NSOperationQueue alloc] init];
        [_downloadEpisodeQueue setMaxConcurrentOperationCount:NSOperationQueueDefaultMaxConcurrentOperationCount];
    }
    
    IGEpisodeDownloadOperation *operation = [IGEpisodeDownloadOperation operationWithEpisode:episode];
    [_downloadEpisodeQueue addOperation:operation];
}

#pragma mark - Refresh Feed

- (void)refreshFeed
{
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    [httpClient syncPodcastFeedWithSuccess:^{
        [self doneLoadingTableViewData];
    } failure:^(NSError *error) {
        // handle error
        [self doneLoadingTableViewData];
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

#pragma mark - IGEpisodeTableViewCellDelegate Methods

/**
 * Invoked when the more info icon is tapped. A popup view is displayed with more information about the episode.
 */
- (void)igEpisodeTableViewCell:(IGEpisodeTableViewCell *)episodeTableViewCell displayMoreInfoAboutEpisodeWithTitle:(NSString *)title
{
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:title];
    
    _episodeMoreInfoViewController = [[self storyboard] instantiateViewControllerWithIdentifier:@"IGEpisodeMoreInfoViewController"];
    [_episodeMoreInfoViewController setEpisode:episode];
    [_episodeMoreInfoViewController setDelegate:self];
    [self presentPopupViewController:_episodeMoreInfoViewController
                       animationType:MJPopupViewAnimationFade];
}

/**
 * Invoked when the download button is tapped. Begins the download of the episode and updates the episode table view cell.
 */
- (void)igEpisodeTableViewCell:(IGEpisodeTableViewCell *)episodeTableViewCell downloadEpisodeWithTitle:(NSString *)title
{
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:title];
    
    if ([self episodeIsDownloading:episode])
    {
        [self removeEpisodeFromDownloadQueue:episode];
    }
    else
    {
        [self addEpisodeToDownloadQueue:episode];
    }
}

#pragma mark - IGEpisodeMoreInfoViewControllerDelegate

- (void)igEpisodeMoreInfoViewControllerPlayButtonTapped:(IGEpisodeMoreInfoViewController *)viewController
{
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[[viewController episode] title]];
    
    [self dismissPopupViewControllerWithanimationType:MJPopupViewAnimationFade];
    _episodeMoreInfoViewController = nil;

    [self playEpisode:episode];
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

#pragma mark - Feedback
#ifdef TESTING
- (IBAction)launchFeedback
{
    [TestFlight openFeedbackView];
}
#endif

@end
