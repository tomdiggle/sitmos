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

#import "IGEpisode.h"

#import "IGHTTPClient.h"
#import "IGDefines.h"
#import "NSDate+Helper.h"

NSString * const IGEpisodeDateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";

@interface IGEpisode ()

/**
 * Indicates if the episode has been listened to.
 */
@property (nonatomic, strong) NSNumber *played;

@end

@implementation IGEpisode

@dynamic duration;
@dynamic fileSize;
@dynamic imageURL;
@dynamic pubDate;
@dynamic summary;
@dynamic title;
@dynamic mediaType;
@dynamic downloadURL;
@dynamic progress;
@dynamic played;

#pragma mark - Import Podcast Feed Items

+ (void)importPodcastFeedItems:(NSArray *)feed
                    completion:(void (^) (BOOL success, NSError *error))completion
{
    if ([feed count] == 0)
    {
        if (completion)
        {
            completion(YES, nil);
        }
        return;
    }
    
    NSDate *latestEpisodePubDate = [NSDate dateFromString:[[feed lastObject] valueForKey:@"pubDate"]
                                               withFormat:IGEpisodeDateFormat];
    NSUInteger episodesCount = [IGEpisode MR_countOfEntities];
    
    __block IGEpisode *episode = nil;
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
        [feed enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            episode = [IGEpisode episodeWithTitle:title
                                        inContext:localContext];
            [episode MR_importValuesForKeysWithObject:obj];
            
            if ((episodesCount == 0 && [latestEpisodePubDate isEqualToDate:[episode pubDate]]) ||
                (episodesCount > 0 && ([latestEpisodePubDate isEqualToDate:[episode pubDate]] || [[episode pubDate] compare:latestEpisodePubDate] == NSOrderedAscending)))
            {
                // If there are no episodes saved, only mark the latest episode as unplayed or if there are episodes already saved, mark all new episodes as unplayed
                [episode markAsPlayed:NO];
            }
        }];
    } completion:^(BOOL success, NSError *error) {
        if (completion)
        {
            completion(success, error);
        }
    }];
}

+ (IGEpisode *)episodeWithTitle:(NSString *)title inContext:(NSManagedObjectContext *)context
{
    IGEpisode *episode = [self MR_findFirstByAttribute:@"title"
                                             withValue:title
                                             inContext:context];
    if (!episode)
    {
        episode = [self MR_createInContext:context];
        [episode setTitle:title];
    }
    
    return episode;
}

#pragma mark - File Management

+ (NSURL *)episodesDirectory
{
    static NSURL *episodesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *cacheDir = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory
                                                                  inDomains:NSUserDomainMask] lastObject];
        episodesDirectory = [cacheDir URLByAppendingPathComponent:@"Episodes"];
        
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtURL:episodesDirectory withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create episodes dir at %@, reason %@", episodesDirectory, [error localizedDescription]);
        }
    });
    
    return episodesDirectory;
}

- (NSString *)fileName
{
    return [NSString stringWithFormat:@"%@.mp3", [self title]];
}

- (NSURL *)fileURL
{
    return [[IGEpisode episodesDirectory] URLByAppendingPathComponent:[self fileName]];
}

- (NSString *)readableFileSize
{
    if ([[self fileSize] isEqualToNumber:@0])
    {
        return @"N/A";
    }
    
    return [NSByteCountFormatter stringFromByteCount:[[self fileSize] longLongValue]
                                          countStyle:NSByteCountFormatterCountStyleBinary];
}

- (void)deleteDownloadedEpisode
{
    NSError *error = nil;
    if (![[NSFileManager defaultManager] removeItemAtPath:[[self fileURL] path] error:&error])
    {
        NSLog(@"Failed to delete episode at %@, reason %@", [[self fileURL] path], [error localizedDescription]);
    }
}

- (BOOL)isDownloaded
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[[self fileURL] path]];
}

- (BOOL)isDownloading
{
    NSArray *request = @[[NSURL URLWithString:[self downloadURL]], [self fileURL]];
    NSArray *currentDownloadRequests = [[IGHTTPClient sharedClient] currentDownloadRequests];
    return [currentDownloadRequests containsObject:request];
}

#pragma mark - File Media Type

- (BOOL)isAudio
{
    return ([[self mediaType] isEqualToString:@"audio/mpeg"]);
}

#pragma mark - Played/Unplayed Management

- (void)markAsPlayed:(BOOL)played
{
    [self setPlayed:@(played)];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults boolForKey:IGShowApplicationBadgeForUnseenKey])
    {
        NSInteger iconBadgeNumber = played ? [[UIApplication sharedApplication] applicationIconBadgeNumber] - 1 : [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:iconBadgeNumber];
    }
    
    if (played && [userDefaults boolForKey:IGAutoDeleteAfterFinishedPlayingKey])
    {
        [self deleteDownloadedEpisode];
    }
}

- (BOOL)isPlayed
{
    return [[self played] boolValue];
}

- (IGEpisodePlayedStatus)playedStatus
{
    if ([self isPlayed])
    {
        return IGEpisodePlayedStatusPlayed;
    }
    else if (![self isPlayed] && ![[self progress] isEqualToNumber:@0])
    {
        return IGEpisodePlayedStatusHalfPlayed;
    }
    else
    {
        return IGEpisodePlayedStatusUnplayed;
    }
}

- (IGEpisodeDownloadStatus)downloadStatus
{
    if ([self isDownloaded])
    {
        return IGEpisodeDownloadStatusDownloaded;
    }
    else if ([self isDownloading])
    {
        return IGEpisodeDownloadStatusDownloading;
    }
    else
    {
        return IGEpisodeDownloadStatusNotDownloading;
    }
}

@end
