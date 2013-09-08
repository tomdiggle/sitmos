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

#import "IGEpisodeImporter.h"

#import "TDNotificationPanel.h"
#import "TSLibraryImport.h"
#import "RIButtonItem.h"
#import "UIAlertView+Blocks.h"

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface IGEpisodeImporter ()

@property (nonatomic, copy) NSURL *destinationDirectory;
@property (nonatomic, copy) NSArray *episodes;
@property (nonatomic, strong) UIView *notificationView;
@property (nonatomic, assign) NSUInteger episodesImported;
@property (nonatomic, assign) NSUInteger episodesToImport;
@property (nonatomic, strong) TDNotificationPanel *progressNotification;

@end

@implementation IGEpisodeImporter

#pragma mark - Class Methods

+ (NSArray *)episodesInMediaLibrary
{
#if TARGET_IPHONE_SIMULATOR
    // Searching for media while targeting the simulator doesn't work, so just skip it.
    return [NSArray array];
#endif
    
    MPMediaPropertyPredicate *albumTitlePredicate = [MPMediaPropertyPredicate predicateWithValue:@"Stuck in the Middle of Somewhere"
                                                                                     forProperty:MPMediaItemPropertyAlbumTitle];
    MPMediaQuery *mediaQuery = [[MPMediaQuery alloc] init];
    [mediaQuery addFilterPredicate:albumTitlePredicate];
    [mediaQuery setGroupingType:MPMediaGroupingPodcastTitle];
    
    return [mediaQuery items];
}

#pragma mark - Initializers

- (id)initWithEpisodes:(NSArray *)episodes destinationDirectory:(NSURL *)destinationDirectory notificationView:(UIView *)view
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    self.episodes = episodes;
    self.destinationDirectory = destinationDirectory;
    self.notificationView = view;
    self.episodesImported = 0;
    self.episodesToImport = 0;
    
    return self;
}

#pragma mark - Show Alert

- (void)showAlert
{
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"No", nil)];
    cancelItem.action = ^{
        if (self.completion)
        {
            self.completion(0, YES, nil);
        }
    };
    RIButtonItem *importItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Import", nil)];
    importItem.action = ^{
        [self startImport];
    };
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"ImportEpisodesTitle", nil)
                                                        message:NSLocalizedString(@"ImportEpisodesDesc", nil)
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:importItem, nil];
    [alertView show];
}

#pragma mark - Import Episodes

- (void)startImport
{
    if (self.notificationView)
    {
        self.progressNotification = [TDNotificationPanel showNotificationInView:self.notificationView
                                                                          title:NSLocalizedString(@"ImportingEpisodes", nil)
                                                                       subtitle:nil
                                                                           type:TDNotificationTypeMessage
                                                                           mode:TDNotificationModeActivityIndicator
                                                                    dismissible:NO];
    }
    
    [self.episodes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *title = [obj valueForProperty:MPMediaItemPropertyTitle];
        NSURL *assetURL = [obj valueForProperty:MPMediaItemPropertyAssetURL];
        if (!assetURL)
        {
            return;
        }
        
        [self importAssetAtURL:assetURL withTitle:title];
    }];
}

- (void)importAssetAtURL:(NSURL *)assetURL withTitle:(NSString *)title
{
    self.episodesToImport += 1;
    
    // Create destination URL
    NSString *ext = [TSLibraryImport extensionForAssetURL:assetURL];
    NSURL *destDir = [[self.destinationDirectory URLByAppendingPathComponent:title] URLByAppendingPathExtension:ext];
    
    // We're responsible for making sure the destination url doesn't already exist
    [[NSFileManager defaultManager] removeItemAtURL:destDir error:nil];
    
    // Create the import object
    TSLibraryImport *import = [[TSLibraryImport alloc] init];
    [import importAsset:assetURL toURL:destDir completionBlock:^(TSLibraryImport *import) {
        self.episodesImported += 1;
        
        if (self.episodesToImport == self.episodesImported)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self importFinished];
                
                if (self.completion)
                {
                    self.completion(self.episodesImported, YES, nil);
                }
            });
        }
        
        if (import.status != AVAssetExportSessionStatusCompleted)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self importFailed:[import error]];
                
                if (self.completion)
                {
                    self.completion(0, NO, [import error]);
                }
            });
            import = nil;
        }
    }];
}

- (void)importFinished
{
    if (!self.notificationView)
    {
        return;
    }
    
    // Hide the progress notification
    [self.progressNotification hide];
    
    // Show a notification informing the user that the import was a success
    [TDNotificationPanel showNotificationInView:self.notificationView
                                          title:[NSString stringWithFormat:NSLocalizedString(@"ImportedEpisodes", @"text label for imported # episodes"), self.episodesImported]
                                       subtitle:nil
                                           type:TDNotificationTypeSuccess
                                           mode:TDNotificationModeText
                                    dismissible:YES
                                 hideAfterDelay:3];
}

- (void)importFailed:(NSError *)error
{
    if (!self.notificationView)
    {
        return;
    }
    
    // Hide the progress notification
    [self.progressNotification hide];
    
    // Show a notification informing the user that the import failed
    [TDNotificationPanel showNotificationInView:self.notificationView
                                          title:NSLocalizedString(@"ImportFailed", @"text label for import failed")
                                       subtitle:[error localizedDescription]
                                           type:TDNotificationTypeError
                                           mode:TDNotificationModeText
                                    dismissible:YES
                                 hideAfterDelay:3];
}

@end
