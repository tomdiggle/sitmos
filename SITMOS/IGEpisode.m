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

- (NSUInteger)downloadedFileSize
{
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:[self filePath]
                                                             error:nil] fileSize];
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
    
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    if ([[mediaPlayer episode] isEqual:self])
    {
        [mediaPlayer stop];
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:[self filePath]
                                               error:nil];
}

- (BOOL)isCompletelyDownloaded
{
    NSUInteger fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[self filePath]
                                                                            error:nil] fileSize];
    //    TFLog(@"%@ - Saved: %i Actual: %i", [self title], [[self fileSize] unsignedIntegerValue], fileSize);
    if (fileSize != 0 && fileSize > [[self fileSize] unsignedIntegerValue])
    {
        return YES;
    }
    
    return NO;
}

- (BOOL)isPartiallyDownloaded
{
    NSUInteger fileSize = [[[NSFileManager defaultManager] attributesOfItemAtPath:[self filePath]
                                                                            error:nil] fileSize];
    //TFLog(@"%@ - %i == %i", [self title], [[self fileSize] unsignedIntegerValue], fileSize);
    if (fileSize > 0 && fileSize < [[self fileSize] unsignedIntegerValue])
    {
        return YES;
    }
    
    return NO;
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
