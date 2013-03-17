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

@interface IGEpisode ()

/**
 * Indicates if the episode has been listened to.
 */
@property (nonatomic, strong) NSNumber *played;

@end

@implementation IGEpisode

@dynamic duration;
@dynamic fileName;
@dynamic fileSize;
@dynamic pubDate;
@dynamic summary;
@dynamic title;
@dynamic type;
@dynamic downloadURL;
@dynamic progress;
@dynamic played;

#pragma mark Class Methods

+ (NSURL *)episodesDirectory
{
    static NSURL *episodesDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURL *cacheDir = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory
                                                                  inDomains:NSUserDomainMask] lastObject];
        episodesDirectory = [cacheDir URLByAppendingPathComponent:@"Episodes"];
        
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtURL:episodesDirectory withIntermediateDirectories:YES attributes:nil error:&error])
        {
            NSLog(@"Failed to create episodes dir at %@, reason %@", episodesDirectory, [error localizedDescription]);
        }
    });
    
    return episodesDirectory;
}

#pragma mark - File Management

- (NSURL *)fileURL
{
    return [[IGEpisode episodesDirectory] URLByAppendingPathComponent:[self fileName]];
}

- (NSString *)readableFileSize
{
    NSString *readableFileSize = nil;
    
    // Megabytes
    if (([[self fileSize] longLongValue]/1024/1024) >= 1)
    {
        readableFileSize = [NSString stringWithFormat:@"%lld MB", ([[self fileSize] longLongValue]/1024/1024)];
    }
    
    // Gigabytes
    if (([[self fileSize] longLongValue]/1024/1024/1024) >= 1)
    {
        readableFileSize = [NSString stringWithFormat:@"%lld GB", ([[self fileSize] longLongValue]/1024/1024/1024)];
        
    }
    
    return readableFileSize;
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
    return ([[self type] isEqualToString:@"audio/mpeg"]);
}

- (BOOL)isVideo
{
    return ([[self type] isEqualToString:@"video/mp4"]);
}

#pragma mark - Played/Unplayed Management

- (void)markAsPlayed:(BOOL)played
{
    [self setPlayed:[NSNumber numberWithBool:played]];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL unseenBage = [userDefaults boolForKey:IGSettingUnseenBadge];
    if (unseenBage)
    {
        NSInteger iconBadgeNumber = played ? [[UIApplication sharedApplication] applicationIconBadgeNumber] - 1 : [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
        [[UIApplication sharedApplication] setApplicationIconBadgeNumber:iconBadgeNumber];
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
