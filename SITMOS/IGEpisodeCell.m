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

#import "IGEpisodeCell.h"

#import "IGHTTPClient.h"
#import "AFDownloadRequestOperation.h"
#import "NSDate+Helper.h"

@interface IGEpisodeCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;
@property (nonatomic, weak) IBOutlet UILabel *pubDateAndTimeLeftLabel;
@property (nonatomic, weak) IBOutlet UILabel *downloadSizeProgressLabel;
@property (nonatomic, weak) IBOutlet UIImageView *playedStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *episodeDownloadedImageView;
@property (nonatomic, weak) IBOutlet UIProgressView *downloadProgressView;
@property (nonatomic, strong) NSLayoutConstraint *pubDateAndTimeLeftLayoutConstraint;

@end

@implementation IGEpisodeCell

#pragma mark - Initializers

- (void)awakeFromNib
{
    self.pubDateAndTimeLeftLayoutConstraint = [NSLayoutConstraint constraintWithItem:self.pubDateAndTimeLeftLabel
                                                                           attribute:NSLayoutAttributeLeading
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:self.contentView
                                                                           attribute:NSLayoutAttributeLeading
                                                                          multiplier:1
                                                                            constant:15];
    [self addConstraint:self.pubDateAndTimeLeftLayoutConstraint];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    if (_downloadStatus == IGEpisodeDownloadStatusDownloading)
    {
        IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
        AFDownloadRequestOperation *operation = [httpClient requestOperationForURL:_downloadURL];
        if (operation)
        {
            [_titleLabel setTextColor:[self unplayedColor]];
            
            [_downloadProgressView setHidden:NO];
            [_downloadSizeProgressLabel setHidden:NO];
            [_downloadButton setHidden:NO];
            [_summaryLabel setHidden:YES];
            [_playedStatusImageView setHidden:YES];
            [_pubDateAndTimeLeftLabel setHidden:YES];
            [_showNotesButton setHidden:YES];
            
            if ([operation isPaused])
            {
                [_downloadButton setImage:[UIImage imageNamed:@"download-resume-button"]
                                 forState:UIControlStateNormal];
                [_downloadButton setAccessibilityLabel:NSLocalizedString(@"ResumeDownload", @"accessibility label for resume download")];
            }
            else
            {
                [_downloadButton setImage:[UIImage imageNamed:@"download-pause-button"]
                                 forState:UIControlStateNormal];
                [_downloadButton setAccessibilityLabel:NSLocalizedString(@"PauseDownload", @"accessibility label for pause download")];
            }
            
            [operation setProgressiveDownloadProgressBlock:^(AFDownloadRequestOperation *operation, NSInteger bytesRead, long long totalBytesRead, long long totalBytesExpected, long long totalBytesReadForFile, long long totalBytesExpectedToReadForFile) {
                NSString *totalBytesDownloaded = [NSByteCountFormatter stringFromByteCount:totalBytesReadForFile
                                                                            countStyle:NSByteCountFormatterCountStyleDecimal];
                NSString *totalBytesExpectedString = [NSByteCountFormatter stringFromByteCount:totalBytesExpectedToReadForFile
                                                                                    countStyle:NSByteCountFormatterCountStyleBinary];
                [_downloadSizeProgressLabel setText:[NSString stringWithFormat:NSLocalizedString(@"EpisodeDownloadProgress", @"text label for episode download progress"), totalBytesDownloaded, totalBytesExpectedString]];
                
                [_downloadProgressView setProgress:totalBytesReadForFile / (float)totalBytesExpectedToReadForFile
                                          animated:YES];
            }];
        }
        else
        {
            [self setDownloadStatus:IGEpisodeDownloadStatusNotDownloading];
        }
    }
    else
    {
        [_summaryLabel setHidden:NO];
        [_playedStatusImageView setHidden:NO];
        [_pubDateAndTimeLeftLabel setHidden:NO];
        [_showNotesButton setHidden:NO];
        [_downloadProgressView setHidden:YES];
        [_downloadSizeProgressLabel setHidden:YES];
        [_downloadButton setHidden:YES];
    }
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGEpisodeDownloadStatus)downloadStatus
{
    if (downloadStatus == IGEpisodeDownloadStatusDownloaded)
    {
        [_episodeDownloadedImageView setHidden:NO];
    }
    else
    {
        [_episodeDownloadedImageView setHidden:YES];
    }
    
    _downloadStatus = downloadStatus;
    
    [self setNeedsLayout];
}

- (void)setPlayedStatus:(IGEpisodePlayedStatus)playedStatus
{    
    if (playedStatus == IGEpisodePlayedStatusUnplayed)
    {
        [self.pubDateAndTimeLeftLayoutConstraint setConstant:28];
        [self.playedStatusImageView setImage:[UIImage imageNamed:@"episode-unplayed-icon"]];
        [self.playedStatusImageView setHighlightedImage:[UIImage imageNamed:@"episode-unplayed-icon-highlighted"]];
        [self.titleLabel setTextColor:[self unplayedColor]];
    }
    else if (playedStatus == IGEpisodePlayedStatusHalfPlayed)
    {
        [self.pubDateAndTimeLeftLayoutConstraint setConstant:28];
        [self.playedStatusImageView setImage:[UIImage imageNamed:@"episode-half-played-icon"]];
        [self.playedStatusImageView setHighlightedImage:[UIImage imageNamed:@"episode-half-played-icon-highlighted"]];
        [self.titleLabel setTextColor:[self unplayedColor]];
    }
    else
    {
        [self.pubDateAndTimeLeftLayoutConstraint setConstant:15];
        [self.playedStatusImageView setImage:nil];
        [self.playedStatusImageView setHighlightedImage:nil];
        [self.titleLabel setTextColor:[self playedColor]];
    }
    
    _playedStatus = playedStatus;
    
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title
{
    if ([title isEqualToString:_title]) return;
    
    _title = title;
    
    [_titleLabel setText:title];
}

- (void)setSummary:(NSString *)summary
{
    if ([summary isEqualToString:_summary]) return;
    
    _summary = summary;
    
    [_summaryLabel setText:summary];
}

- (void)setPubDate:(NSDate *)pubDate
{
    if ([pubDate isEqualToDate:_pubDate]) return;
    
    _pubDate = pubDate;
    
    [_pubDateAndTimeLeftLabel setText:[NSString stringWithFormat:@"%@ - %@", [NSDate stringFromDate:pubDate withFormat:@"dd MMM yyyy"], _timeLeft]];
}

- (void)setTimeLeft:(NSString *)timeLeft
{
    if ([timeLeft isEqualToString:_timeLeft]) return;
    
    _timeLeft = timeLeft;
    
    [_pubDateAndTimeLeftLabel setText:[NSString stringWithFormat:@"%@ - %@", [NSDate stringFromDate:_pubDate withFormat:@"dd MMM yyyy"], timeLeft]];
}

#pragma mark - Color's for the labels

- (UIColor *)playedColor
{
    return [UIColor colorWithRed:0.701 green:0.701 blue:0.701 alpha:1];
}

- (UIColor *)unplayedColor
{
    return [UIColor blackColor];
}

@end
