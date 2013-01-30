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

#pragma mark - Memory Management

- (void)dealloc
{
    _delegate = nil;
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGEpisodeDownloadStatus)downloadStatus
{
    _downloadStatus = downloadStatus;
    
    switch (downloadStatus)
    {
        case IGEpisodeDownloadStatusDownloaded:
            [_downloadProgressView setAlpha:0.0f];
            [_downloadEpisodeButton setAlpha:0.0f];
            break;
         
        case IGEpisodeDownloadStatusDownloading:
            [_downloadProgressView setAlpha:1.0f];
            [_downloadEpisodeButton setAlpha:1.0f];
            [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-pause-button"] forState:UIControlStateNormal];
            break;
            
        case IGEpisodeDownloadStatusNotDownloaded:
            [_downloadProgressView setAlpha:0.0f];
            [_downloadEpisodeButton setAlpha:1.0f];
            [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-start-button"] forState:UIControlStateNormal];
            break;
            
            case IGEpisodeDownloadStatusDownloadingPaused:
            [_downloadProgressView setAlpha:1.0f];
            [_downloadEpisodeButton setAlpha:1.0f];
            [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-resume-button"] forState:UIControlStateNormal];
            break;
        default:
            break;
    }
}

- (void)setPlayedStatus:(IGEpisodePlayedStatus)playedStatus
{
    _playedStatus = playedStatus;
    
    switch (playedStatus)
    {
        case IGEpisodePlayedStatusPlayed:
            NSLog(@"Episode %@ played", self.episodeTitleLabel.text);
            [_playedStatusIconImageView setImage:nil];
//            [_episodeDateAndDurationLabel setFrame:CGRectMake(11.0f, 25.0f, 144.0f, 21.0f)];
            break;
            
        case IGEpisodePlayedStatusHalfPlayed:
            NSLog(@"Episode %@ half played", self.episodeTitleLabel.text);
            [_playedStatusIconImageView setImage:[UIImage imageNamed:@"half-played-icon"]];
//            [_episodeDateAndDurationLabel setFrame:CGRectMake(27.0f, 25.0f, 144.0f, 21.0f)];
            break;
            
        case IGEpisodePlayedStatusUnplayed:
            NSLog(@"Episode %@ unplayed", self.episodeTitleLabel.text);
            [_playedStatusIconImageView setImage:[UIImage imageNamed:@"unplayed-icon"]];
//            [_episodeDateAndDurationLabel setFrame:CGRectMake(27.0f, 25.0f, 144.0f, 21.0f)];
            break;
            
        default:
            break;
    }
}

#pragma mark - IBAction Methods

- (IBAction)downloadButtonTapped:(id)sender
{
    if (![sender isKindOfClass:[UIButton class]]) return;
    
    [_delegate igEpisodeTableViewCell:self
             downloadEpisodeButtonTapped:sender];
}

- (IBAction)moreInfoButtonTapped:(id)sender
{
    [_delegate igEpisodeTableViewCell:self
 displayMoreInfoAboutEpisodeWithTitle:[_episodeTitleLabel text]];
}

@end
