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

/* Episode Download Statuses */
typedef enum {
    IGEpisodeDownloadStatusNotDownloading,
    IGEpisodeDownloadStatusDownloading,
    IGEpisodeDownloadStatusDownloaded
} IGEpisodeDownloadStatus;

/* Episode Played Statuses */
typedef enum {
    IGEpisodePlayedStatusPlayed,
    IGEpisodePlayedStatusUnplayed,
    IGEpisodePlayedStatusHalfPlayed
} IGEpisodePlayedStatus;

/**
 * The IGEpisode class provides access to a episode entity.
 */

@interface IGEpisode : NSManagedObject

/**
 * Indicates how long the episode is in time.
 */
@property (nonatomic, strong) NSString *duration;

/**
 * Indicates the name of the file the episode will be saved as when downloaded.
 */
@property (nonatomic, strong) NSString *fileName;

/**
 * Indicates the file size of the episode.
 */
@property (nonatomic, strong) NSNumber *fileSize;

/**
 * Indicates the date the episode was published.
 */
@property (nonatomic, strong) NSDate *pubDate;

/**
 * Indicates a summary describing what the episode is about.
 */
@property (nonatomic, strong) NSString *summary;

/**
 * Indicates the title of the episode.
 */
@property (nonatomic, strong) NSString *title;

/**
 * Indicates what media type the episode is eg. Audio.
 */
@property (nonatomic, strong) NSString *type;

/**
 * Indicates the download URL of the episode.
 */
@property (nonatomic, strong) NSString *downloadURL;

/**
 * Indicates the current progress of the episode.
 *
 * Used to to resume playback of episode.
 */
@property (nonatomic, strong) NSNumber *progress;

#pragma mark - File Management

/**
 * @name File Management
 */

/**
 * Returns the directory the downloaded episodes are stored in.
 *
 * @return The directory the downloaded episodes are stored in.
 */
+ (NSURL *)episodesDirectory;

/**
 * Returns the full file path of the episode.
 *
 * Episodes are stored in <APP>/Library/Caches/Episodes
 */
- (NSURL *)fileURL;

/**
 * Returns a human readable file size.
 */
- (NSString *)readableFileSize;

/**
 * Deletes the downloaded episode file from the directory it is saved in.
 *
 * If the episode is currently being played, it will be stoped before it gets deleted.
 */
- (void)deleteDownloadedEpisode;

/**
 * @return YES if the episode is audio has been completely downloaded, NO otherwise.
 */
- (BOOL)isDownloaded;

/**
 * @return YES if the episode is audio is partially downloaded, NO otherwise.
 */
- (BOOL)isDownloading;

#pragma mark - File Media Type

/**
 * @name File Media Type
 */

/**
 * @return YES if the episode is audio, NO otherwise.
 */
- (BOOL)isAudio;

/**
 * @return YES if the episode is video, NO otherwise.
 */
- (BOOL)isVideo;

#pragma mark - Played/Unplayed Management

/**
 * @name Played/Unplayed Management
 */

/**
 * Marks the episode has played or unplayed.
 *
 * If the setting for unseen badge is set to YES it will increase/decrease the icon badge number by 1.
 *
 * @param BOOL YES will mark episode as played, NO will mark episode as unplayed.
 */
- (void)markAsPlayed:(BOOL)played;

/**
 * @return YES if the episode has been played, NO otherwise.
 */
- (BOOL)isPlayed;

/**
 * Returns the played status of the episode.
 */
- (IGEpisodePlayedStatus)playedStatus;

/**
 * Returns the download status of the episode.
 */
- (IGEpisodeDownloadStatus)downloadStatus;

@end
