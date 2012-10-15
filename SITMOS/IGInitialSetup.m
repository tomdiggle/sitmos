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

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

#import "IGInitialSetup.h"
#import "IGAppDelegate.h"
#import "IGFeedRefreshOperation.h"
#import "RIButtonItem.h"
#import "UIAlertView+Blocks.h"
#import "MBProgressHUD.h"
#import "TSLibraryImport.h"

@interface IGInitialSetup () <MBProgressHUDDelegate>

@property (nonatomic, strong) MBProgressHUD *HUD;
@property NSUInteger numberOfEpisodesToImport;
@property NSUInteger numberOfEpisodesImported;

@end

@implementation IGInitialSetup

#pragma mark - Class Methods

+ (IGInitialSetup *)runInitialSetup
{
    return [[self alloc] init];
}

+ (void)createEpisodesDirectory
{
    NSURL *episodesDirectory = [[IGInitialSetup cachesDirectory] URLByAppendingPathComponent:@"Episodes"];
    [[NSFileManager defaultManager] createDirectoryAtURL:episodesDirectory withIntermediateDirectories:NO attributes:nil error:nil];
}

+ (NSURL *)cachesDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask] lastObject];;
}

+ (NSURL *)episodesDirectory
{
    return [[IGInitialSetup cachesDirectory] URLByAppendingPathComponent:@"Episodes" isDirectory:YES];
}

#pragma mark - Initializers

- (id)init
{
    self = [super init];
    
    _numberOfEpisodesToImport = 0;
    _numberOfEpisodesImported = 0;
    
    IGAppDelegate *appDelegate = (IGAppDelegate *)[[UIApplication sharedApplication] delegate];
    _HUD = [[MBProgressHUD alloc] initWithWindow:[appDelegate window]];
    [_HUD setDelegate:self];
    _HUD.mode = MBProgressHUDModeIndeterminate;
    _HUD.labelFont = [UIFont fontWithName:IGFontNameMedium size:16.0f];
    _HUD.detailsLabelFont = [UIFont fontWithName:IGFontNameRegular size:12.0f];
    _HUD.dimBackground = YES;
    [[appDelegate window] addSubview:_HUD];
    
    [self start];
    
    return self;
}

- (void)start
{
    // Register default settings
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setBool:YES forKey:IGSettingCellularDataStreaming];
    [userDefaults setBool:YES forKey:IGSettingCellularDataDownloading];
    [userDefaults setBool:NO forKey:IGSettingEpisodesDelete];
    [userDefaults setBool:NO forKey:IGSettingUnseenBadge];
    
    // Create the directory the downloaded episodes will be stored in
    [IGInitialSetup createEpisodesDirectory];
    
    // Search for any episodes already on the device
    MPMediaPropertyPredicate *albumTitlePredicate = [MPMediaPropertyPredicate predicateWithValue:@"Stuck in the Middle of Somewhere"
                                                                                     forProperty:MPMediaItemPropertyAlbumTitle];
    MPMediaQuery *albumTitleQuery = [[MPMediaQuery alloc] init];
    [albumTitleQuery addFilterPredicate:albumTitlePredicate];
    [albumTitleQuery setGroupingType:MPMediaGroupingPodcastTitle];
    NSArray *itemsFromAlbumTitleQuery = [albumTitleQuery items];
    
    if ([itemsFromAlbumTitleQuery count] == 0)
    {
        // No episodes found on iPod, go directly to fetching the podcast feed, do not pass go, do not collect $200 
        [self fetchPodcastFeed];
        return;
    }
    
    // Ask user if they want to import the episodes
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"No", "text label for no")];
    cancelItem.action = ^{
        [self fetchPodcastFeed];
    };
    RIButtonItem *importItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Yes", "text label for yes")];
    importItem.action = ^{
        _HUD.labelText = NSLocalizedString(@"ImportingEpisodes", @"text label for importing episodes");
        _HUD.detailsLabelText = NSLocalizedString(@"ThisMayTakeAWhile", @"text label for this may take a while");
        [_HUD show:YES];
        [self importEpisodesAlreadyOnDevice:itemsFromAlbumTitleQuery];
    };
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ImportEpisodesTitle", "text label for import episodes title")
                                                        message:NSLocalizedString(@"ImportEpisodesDesc", "text label for import episodes desc")
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:importItem, nil];
    [alertView show];
}

#pragma mark - Fetch Podcast Feed

- (void)fetchPodcastFeed
{
    if ([_HUD alpha] == 0)
    {
        [_HUD show:YES];
    }
    
    _HUD.labelText = NSLocalizedString(@"FetchingFeed", @"text label for fetching feed");
    _HUD.detailsLabelText = nil;
    
    NSOperationQueue *operationQueue = [[NSOperationQueue alloc] init];
    IGFeedRefreshOperation *operation = [IGFeedRefreshOperation refreshFeedWithURL:[NSURL URLWithString:IGSITMOSFeedURL]];
    operation.completionBlock = ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            // Must be called on main thread so the HUD gets hidden
            _HUD.customView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"checkmark"]];
            _HUD.mode = MBProgressHUDModeCustomView;
            _HUD.labelText = NSLocalizedString(@"Completed", @"text label for Completed");
            [_HUD hide:YES afterDelay:1];
        });
    };
    [operationQueue addOperation:operation];
}

#pragma mark - Import Episodes

- (void)importEpisodesAlreadyOnDevice:(NSArray *)episodes
{
    [episodes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *title = [obj valueForProperty:MPMediaItemPropertyTitle];
        NSURL *assetURL = [obj valueForProperty:MPMediaItemPropertyAssetURL];
        if (!assetURL)
        {
            return;
        }
        [self exportAssetAtURL:assetURL withTitle:title];
    }];
}

- (void)exportAssetAtURL:(NSURL *)assetURL withTitle:(NSString *)title
{
    _numberOfEpisodesToImport += 1;
    
    // Create destination URL
    NSString *ext = [TSLibraryImport extensionForAssetURL:assetURL];
    NSURL *outURL = [[[IGInitialSetup episodesDirectory] URLByAppendingPathComponent:title] URLByAppendingPathExtension:ext];
    
    // We're responsible for making sure the destination url doesn't already exist
    [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
    
    // Create the import object
    TSLibraryImport *import = [[TSLibraryImport alloc] init];
    [import importAsset:assetURL toURL:outURL completionBlock:^(TSLibraryImport *import) {
        _numberOfEpisodesImported += 1;
        
        if (_numberOfEpisodesToImport == _numberOfEpisodesImported)
        {
            // All episodes imported, no fetch the podcast feed
            [self fetchPodcastFeed];
        }
        
        if (import.status != AVAssetExportSessionStatusCompleted)
        {
            // Something went wrong with the import
            [self presentError:import.error];
            import = nil;
            return;
        }
    }];
}

#pragma mark - MBProgressHUDDelegate methods

- (void)hudWasHidden:(MBProgressHUD *)hud
{
	[_HUD removeFromSuperview];
	_HUD = nil;
}

#pragma mark - Preset Error

- (void)presentError:(NSError *)error
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
														message:[error localizedFailureReason]
													   delegate:nil
											  cancelButtonTitle:NSLocalizedString(@"OK", "text label for ok")
											  otherButtonTitles:nil];
	[alertView show];
}

@end
