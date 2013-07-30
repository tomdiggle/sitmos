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

#import "TSLibraryImport.h"

#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

@interface IGEpisodeImporter ()


@property (nonatomic, copy) NSURL *destinationDirectory;
@property (nonatomic, copy) NSArray *episodes;
@property (nonatomic, copy) void(^completion)(NSUInteger episodesImported, BOOL success, NSError *error);
@property (nonatomic, assign) NSUInteger episodesImported;
@property (nonatomic, assign) NSUInteger episodesToImport;

@end

@implementation IGEpisodeImporter

+ (NSArray *)episodesOnDevice
{
#if TARGET_IPHONE_SIMULATOR
    // Searching for media while targeting the simulator doesn't work, so just skip it.
    return nil;
#endif
    
    MPMediaPropertyPredicate *albumTitlePredicate = [MPMediaPropertyPredicate predicateWithValue:@"Stuck in the Middle of Somewhere"
                                                                                     forProperty:MPMediaItemPropertyAlbumTitle];
    MPMediaQuery *mediaQuery = [[MPMediaQuery alloc] init];
    [mediaQuery addFilterPredicate:albumTitlePredicate];
    [mediaQuery setGroupingType:MPMediaGroupingPodcastTitle];
    
    return [mediaQuery items];
}

+ (instancetype)importEpisodes:(NSArray *)episodes destinationDirectory:(NSURL *)destinationDirectory completion:(void (^)(NSUInteger episodesImported, BOOL success, NSError *error))completion
{
    IGEpisodeImporter *importer = [[IGEpisodeImporter alloc] initWithEpisodes:episodes];
    [importer setDestinationDirectory:destinationDirectory];
    [importer setCompletion:completion];
    
    return importer;
}

- (id)initWithEpisodes:(NSArray *)episodes
{
    if (!(self = [super init])) return nil;
    
    _episodes = episodes;
    _episodesImported = 0;
    _episodesToImport = 0;
    
    return self;
}

- (void)importEpisodes
{
    [_episodes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
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
    _episodesToImport += 1;
    
    // Create destination URL
    NSString *ext = [TSLibraryImport extensionForAssetURL:assetURL];
    NSURL *destDir = [[_destinationDirectory URLByAppendingPathComponent:title] URLByAppendingPathExtension:ext];
    
    // We're responsible for making sure the destination url doesn't already exist
    [[NSFileManager defaultManager] removeItemAtURL:destDir error:nil];
    
    // Create the import object
    TSLibraryImport *import = [[TSLibraryImport alloc] init];
    [import importAsset:assetURL toURL:destDir completionBlock:^(TSLibraryImport *import) {
        _episodesImported += 1;
        
        if (_episodesToImport == _episodesImported)
        {
            // All episodes imported
            if (_completion)
            {
                _completion(_episodesToImport, YES, nil);
            }
        }
        
        if (import.status != AVAssetExportSessionStatusCompleted)
        {
            // Something went wrong with the import
            if (_completion)
            {
                _completion(_episodesToImport, NO, [import error]);
                import = nil;
            }
        }
    }];
}

@end
