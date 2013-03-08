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
#import <CommonCrypto/CommonDigest.h>

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

+ (NSString *)cacheFolder
{
    static NSString *cacheFolder;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cacheDir = NSTemporaryDirectory();
        cacheFolder = [cacheDir stringByAppendingPathComponent:@"Incomplete"]; // This is the temp file defined by AFDownloadRequestOperation
        
        // ensure all cache directories are there (needed only once)
        NSError *error = nil;
        if(![[NSFileManager new] createDirectoryAtPath:cacheFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Failed to create cache directory at %@", cacheFolder);
        }
    });
    return cacheFolder;
}

// calculates the MD5 hash of a key
+ (NSString *)md5StringForString:(NSString *)string
{
    const char *str = [string UTF8String];
    unsigned char r[CC_MD5_DIGEST_LENGTH];
    CC_MD5(str, strlen(str), r);
    return [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
            r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], r[10], r[11], r[12], r[13], r[14], r[15]];
}

#pragma mark - File Management

- (NSString *)filePath
{
    NSArray *cachesDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *episodesDirectory = [[cachesDirectory objectAtIndex:0] stringByAppendingString:@"/Episodes/"];
    return [episodesDirectory stringByAppendingString:[self fileName]];
}

- (NSURL *)fileURL
{
    NSURL *cachesDirectory = [[[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory 
                                                                     inDomains:NSUserDomainMask] lastObject];
    NSURL *storeURL = [cachesDirectory URLByAppendingPathComponent:@"Episodes"
                                                       isDirectory:YES];
    return [storeURL URLByAppendingPathComponent:[self fileName]];
}

- (NSString *)tempPath
{
    NSString *md5URLString = [[self class] md5StringForString:[self filePath]];
    NSString *tempPath = [[[self class] cacheFolder] stringByAppendingPathComponent:md5URLString];
    
    return tempPath;
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
    if (![[NSFileManager defaultManager] fileExistsAtPath:[self filePath]]) return;
    
    [[NSFileManager defaultManager] removeItemAtPath:[self filePath]
                                               error:nil];
}

- (BOOL)isCompletelyDownloaded
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self filePath]];
}

- (BOOL)isPartiallyDownloaded
{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self tempPath]];
}

#pragma mark - File Media Type

- (BOOL)isAudio
{
    if ([[self type] isEqualToString:@"audio/mpeg"])
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isVideo
{
    if ([[self type] isEqualToString:@"video/mp4"])
    {
        return YES;
    }
    
    return NO;
}

#pragma mark - Played/Unplayed Management

- (void)markAsPlayed:(BOOL)isPlayed
{
    [self setPlayed:[NSNumber numberWithBool:isPlayed]];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    BOOL unseenBage = [userDefaults boolForKey:IGSettingUnseenBadge];
    if (unseenBage)
    {
        NSInteger iconBadgeNumber = isPlayed ? [[UIApplication sharedApplication] applicationIconBadgeNumber] - 1 : [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
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
    if ([self isCompletelyDownloaded])
    {
        return IGEpisodeDownloadStatusDownloaded;
    }
    else if ([self isPartiallyDownloaded])
    {
        return IGEpisodeDownloadStatusDownloading;
    }
    else
    {
        return IGEpisodeDownloadStatusNotDownloading;
    }
}

- (IGEpisode *)nextEpisode
{
    NSPredicate *nextEpisodePredicate = [NSPredicate predicateWithFormat:@"pubDate > %@", [self pubDate]];
    return [IGEpisode MR_findFirstWithPredicate:nextEpisodePredicate
                                       sortedBy:@"pubDate"
                                      ascending:YES];
}

- (IGEpisode *)previousEpisode
{
    NSPredicate *nextEpisodePredicate = [NSPredicate predicateWithFormat:@"pubDate < %@", [self pubDate]];
    return [IGEpisode MR_findFirstWithPredicate:nextEpisodePredicate
                                       sortedBy:@"pubDate"
                                      ascending:NO];
}

@end
