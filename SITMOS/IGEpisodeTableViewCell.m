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

#import "IGEpisodeTableViewCell.h"
#import "DACircularProgressView.h"

@implementation IGEpisodeTableViewCell

- (void)awakeFromNib
{
    [_episodeTitleLabel setFont:[UIFont fontWithName:IGFontNameRegular
                                                size:14.0f]];
    [_episodeDateAndDurationLabel setFont:[UIFont fontWithName:IGFontNameRegular
                                                          size:13.0f]];
}

#pragma mark - Memory Management

- (void)dealloc
{
    _delegate = nil;
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGDownloadStatus)downloadStatus
{
    _downloadStatus = downloadStatus;
        
    switch (downloadStatus)
    {
        case IG_DOWNLOADED:
            [_downloadEpisodeButton setAlpha:0];
            [_downloadProgressView setAlpha:0];
            break;
            
        case IG_DOWNLOADING:
            [self observeDownloadingEpisodeNotification];
            [_downloadEpisodeButton setAlpha:1.0f];
            [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-pause-button"]
                                    forState:UIControlStateNormal];
            [_downloadProgressView setAlpha:1.0f];
            break;
            
        case IG_DOWNLOADING_PAUSED:
            [_downloadEpisodeButton setAlpha:1.0f];
            [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-resume-button"]
                                    forState:UIControlStateNormal];
            [_downloadProgressView setAlpha:1.0f];
            break;
            
        case IG_NOT_DOWNLOADED:
            [_downloadEpisodeButton setAlpha:1.0f];
            [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-start-button"]
                                    forState:UIControlStateNormal];
            [_downloadProgressView setAlpha:0];
            [_downloadProgressView setProgress:0];
            break;
            
        default:
            break;
    }
}

- (void)setPlaybackStatus:(IGPlaybackStatus)playbackStatus
{
    _playbackStatus = playbackStatus;
        
    switch (playbackStatus) 
    {
        case IG_STOPPED:
            if (!_played && _playbackProgress > 0)
            {
                [_helperIconImageView setImage:[UIImage imageNamed:@"half-played-icon"]];
            }
            else if (!_played)
            {
                [_helperIconImageView setImage:[UIImage imageNamed:@"unplayed-icon"]];
            }
            else
            {
                [_helperIconImageView setImage:nil];
            }
            break;
            
        case IG_PAUSED:
        case IG_PLAYING:
            [_helperIconImageView setImage:[UIImage imageNamed:@"episode-playing-icon"]];
            break;
            
        default:
            break;
    }
}

#pragma mark - IBAction Methods

- (IBAction)downloadButtonTapped:(id)sender
{
    [_delegate igEpisodeTableViewCell:self
             downloadEpisodeWithTitle:[_episodeTitleLabel text]];
    
    if (_downloadStatus != IG_DOWNLOADING)
    {
        [self setDownloadStatus:IG_DOWNLOADING];
    }
}

- (IBAction)moreInfoButtonTapped:(id)sender
{
    [_delegate igEpisodeTableViewCell:self
 displayMoreInfoAboutEpisodeWithTitle:[_episodeTitleLabel text]];
}

#pragma mark - Observe Downloading Episode Notification

/**
 * Invoked while episdoe is downloading. Observes the download progress notification while the download is in progress it
 * will update the download progress view. When the download is complete it will remove download progress view from view
 * and remove the observer.
 */
- (void)observeDownloadingEpisodeNotification
{
    __block NSNotification *dataObserver = [[NSNotificationCenter defaultCenter] addObserverForName:IGDownloadProgressNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *note) {
        NSDictionary *userInfo = [note userInfo];
        if (![[_episodeTitleLabel text] isEqual:[userInfo valueForKey:@"episodeTitle"]]) return;
        
        if ([[userInfo valueForKey:@"isCancelled"] boolValue])
        {
            [self setDownloadStatus:IG_DOWNLOADING_PAUSED];
            [[NSNotificationCenter defaultCenter] removeObserver:dataObserver];
        }
        else if ([[userInfo valueForKey:@"isFinished"] boolValue])
        {
            [self setDownloadStatus:IG_DOWNLOADED];
            [[NSNotificationCenter defaultCenter] removeObserver:dataObserver];
        }
        else
        {
            CGFloat progress = [[userInfo valueForKey:@"bytesDownloaded"] floatValue] / [[userInfo valueForKey:@"contentLength"] floatValue];
            [_downloadProgressView setProgress:progress
                                      animated:YES];
        }
    }];
}

@end
