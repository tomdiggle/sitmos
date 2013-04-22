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

#import "IGInitialSetup.h"

#import "IGEpisode.h"
#import "IGDefines.h"
#import "RIButtonItem.h"
#import "UIAlertView+Blocks.h"
#import "TSLibraryImport.h"

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

NSString * const IGInitialSetupImportEpisodes = @"IGInitialSetupImportEpisodes";

@interface IGInitialSetup ()

@property (nonatomic, strong) NSUserDefaults *userDefaults;
@property (nonatomic, assign) NSUInteger numberOfEpisodesToImport;
@property (nonatomic, assign) NSUInteger numberOfEpisodesImported;
@property (nonatomic, copy) void (^completion)(NSUInteger episodesImported, NSError *error);

@end

@implementation IGInitialSetup

#pragma mark - Class Methods

+ (void)runInitialSetupWithCompletion:(void (^)(NSUInteger episodesImported, NSError *error))completion;
{
    IGInitialSetup *setup = [[self alloc] initWithCompletion:completion];
    [setup start];
}

#pragma mark - Initializers

- (id)initWithCompletion:(void (^)(NSUInteger episodesImported, NSError *error))completion
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _userDefaults = [NSUserDefaults standardUserDefaults];
    
    _completion = completion;
    
    _numberOfEpisodesToImport = 0;
    _numberOfEpisodesImported = 0;
    
    return self;
}

- (void)start
{
    [self setUpUserDefaults];
    
    // Only continue if episodes havn't already been searched for
    if ([_userDefaults boolForKey:IGInitialSetupImportEpisodes])
    {
        return;
    }

#if TARGET_IPHONE_SIMULATOR
    // Searching for media while targeting the simulator causes a bunch of errors to be displayed in the console, so just skip it.
    return;
#endif
    
    // Search for any episodes already on the device
    MPMediaPropertyPredicate *albumTitlePredicate = [MPMediaPropertyPredicate predicateWithValue:@"Stuck in the Middle of Somewhere"
                                                                                     forProperty:MPMediaItemPropertyAlbumTitle];
    MPMediaQuery *albumTitleQuery = [[MPMediaQuery alloc] init];
    [albumTitleQuery addFilterPredicate:albumTitlePredicate];
    [albumTitleQuery setGroupingType:MPMediaGroupingPodcastTitle];
    NSArray *itemsFromAlbumTitleQuery = [albumTitleQuery items];
    
    if ([itemsFromAlbumTitleQuery count] == 0)
    {
        _completion(0, nil);
        return;
    }
    
    // Ask user if they want to import the episodes
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"No", "text label for no")];
    cancelItem.action = ^{
        _completion(0, nil);
    };
    RIButtonItem *importItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Yes", "text label for yes")];
    importItem.action = ^{
        [self importEpisodesAlreadyOnDevice:itemsFromAlbumTitleQuery];
    };
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ImportEpisodesTitle", "text label for import episodes title")
                                                        message:NSLocalizedString(@"ImportEpisodesDesc", "text label for import episodes desc")
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:importItem, nil];
    [alertView show];
    
    // Import has happened set IGInitialSetupImportEpisodes to YES so the user isn't asked to import any episodes in the future
    [_userDefaults setBool:YES forKey:IGInitialSetupImportEpisodes];
    [_userDefaults synchronize];
}

#pragma mark - Set Up User Defaults

/**
 * Registers the default settings if they don't already exist.
 */
- (void)setUpUserDefaults
{
    if (![_userDefaults objectForKey:IGSettingCellularDataStreaming])
    {
        [_userDefaults setBool:YES forKey:IGSettingCellularDataStreaming];
    }
    
    if (![_userDefaults objectForKey:IGSettingCellularDataDownloading])
    {
        [_userDefaults setBool:NO forKey:IGSettingCellularDataDownloading];
    }
    
    if (![_userDefaults objectForKey:IGSettingEpisodesDelete])
    {
        [_userDefaults setBool:NO forKey:IGSettingEpisodesDelete];
    }
    
    if (![_userDefaults objectForKey:IGSettingUnseenBadge])
    {
        [_userDefaults setBool:NO forKey:IGSettingUnseenBadge];
    }
    
    if (![_userDefaults objectForKey:IGSettingSkippingForwardTime])
    {
        [_userDefaults setInteger:30 forKey:IGSettingSkippingForwardTime];
    }
    
    if (![_userDefaults objectForKey:IGSettingSkippingBackwardTime])
    {
        [_userDefaults setInteger:30 forKey:IGSettingSkippingBackwardTime];
    }
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
    NSURL *outURL = [[[IGEpisode episodesDirectory] URLByAppendingPathComponent:title] URLByAppendingPathExtension:ext];
    
    // We're responsible for making sure the destination url doesn't already exist
    [[NSFileManager defaultManager] removeItemAtURL:outURL error:nil];
    
    // Create the import object
    TSLibraryImport *import = [[TSLibraryImport alloc] init];
    [import importAsset:assetURL toURL:outURL completionBlock:^(TSLibraryImport *import) {
        _numberOfEpisodesImported += 1;
        
        if (_numberOfEpisodesToImport == _numberOfEpisodesImported)
        {
            // All episodes imported
            _completion(_numberOfEpisodesToImport, nil);
        }
        
        if (import.status != AVAssetExportSessionStatusCompleted)
        {
            // Something went wrong with the import
            _completion(_numberOfEpisodesToImport, [import error]);
            import = nil;
        }
    }];
}

@end
