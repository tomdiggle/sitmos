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

#import "IGHTTPClient.h"
#import "AFDownloadRequestOperation.h"
#import "DACircularProgressView.h"
#import "IGEpisodeDateAndDurationLabel.h"

@implementation IGEpisodeTableViewCell

#pragma mark - Memory Management

- (void)dealloc
{
    _delegate = nil;
}

#pragma mark -

- (void)layoutSubviews
{
    [_downloadProgressView setBackgroundColor:[UIColor clearColor]];
    
    [self displayPlayedStatusIcon];
    
    [super layoutSubviews];
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGEpisodeDownloadStatus)downloadStatus
{
    _downloadStatus = downloadStatus;
    
    switch (downloadStatus)
    {
        case IGEpisodeDownloadStatusNotDownloading:
            [_downloadProgressView setProgress:0.0f];
            [_downloadProgressView setAlpha:0.0f];
            [_downloadEpisodeButton setAlpha:1.0f];
            [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-start-button"] forState:UIControlStateNormal];
            break;
            
        case IGEpisodeDownloadStatusDownloading:
        {
            [_downloadProgressView setAlpha:1.0f];
            [_downloadEpisodeButton setAlpha:1.0f];
            
            IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
            AFDownloadRequestOperation *operation = (AFDownloadRequestOperation *)[httpClient requestOperationForURL:_downloadURL];
            if (operation)
            {
                [operation setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile) {
                    [_downloadProgressView setProgress:totalBytesReadForFile / (float)totalBytesExpectedToReadForFile
                                              animated:YES];
                }];
                
                if ([operation isPaused])
                {
                    [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-resume-button"] forState:UIControlStateNormal];
                }
                else
                {
                    [_downloadEpisodeButton setImage:[UIImage imageNamed:@"download-episode-pause-button"] forState:UIControlStateNormal];
                }
            }
            else
            {
                [self setDownloadStatus:IGEpisodeDownloadStatusNotDownloading];
            }
             
            break;
        }
            
        case IGEpisodeDownloadStatusDownloaded:
            [_downloadProgressView setProgress:0.0f];
            [_downloadProgressView setAlpha:0.0f];
            [_downloadEpisodeButton setAlpha:0.0f];
            break;
        
        default:
            break;
    }
}

#pragma mark - Played Status Icon

- (void)displayPlayedStatusIcon
{
    if (_playedStatus == IGEpisodePlayedStatusUnplayed)
    {
        [_episodeDateAndDurationLabel setDisplayPlayedStatusIcon:YES];
        [_playedStatusIconImageView setImage:[UIImage imageNamed:@"unplayed-icon"]];
    }
    else if (_playedStatus == IGEpisodePlayedStatusHalfPlayed)
    {
        [_episodeDateAndDurationLabel setDisplayPlayedStatusIcon:YES];
        [_playedStatusIconImageView setImage:[UIImage imageNamed:@"half-played-icon"]];
    }
    else if (_playedStatus == IGEpisodePlayedStatusPlayed)
    {
        [_episodeDateAndDurationLabel setDisplayPlayedStatusIcon:NO];
        [_playedStatusIconImageView setImage:nil];
    }
}

#pragma mark - IBAction Methods

- (IBAction)downloadButtonTapped:(id)sender
{
    [_delegate igEpisodeTableViewCell:self
          downloadEpisodeButtonTapped:sender];
}

- (IBAction)moreInfoButtonTapped:(id)sender
{
    [_delegate igEpisodeTableViewCell:self
 displayMoreInfoAboutEpisodeWithTitle:[_episodeTitleLabel text]];
}

@end
