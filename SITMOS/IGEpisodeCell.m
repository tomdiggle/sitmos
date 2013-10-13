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

#import "IGNetworkManager.h"
#import "NSDate+Helper.h"

@interface IGEpisodeCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;
@property (nonatomic, weak) IBOutlet UILabel *pubDateAndTimeLeftLabel;
@property (nonatomic, weak) IBOutlet UILabel *downloadSizeProgressLabel;
@property (nonatomic, weak) IBOutlet UIImageView *playedStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *episodeDownloadedImageView;
@property (nonatomic, weak) IBOutlet UIProgressView *downloadProgressView;
@property (nonatomic, weak) IBOutlet UIButton *downloadButton;
@property (nonatomic, strong) NSTimer *downloadProgressTimer;
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
    
    NSURLSessionDownloadTask *sessionTask = [IGNetworkManager downloadTaskForURL:self.downloadURL];
    if (sessionTask)
    {
        [self.titleLabel setTextColor:[self unplayedColor]];
        
        [self.downloadProgressView setHidden:NO];
        [self.downloadSizeProgressLabel setHidden:NO];
        [self.downloadButton setHidden:NO];
        [self.summaryLabel setHidden:YES];
        [self.playedStatusImageView setHidden:YES];
        [self.pubDateAndTimeLeftLabel setHidden:YES];
        [self.showNotesButton setHidden:YES];
        
        [self updateDownloadButtonImageForSessionState:sessionTask.state];
        
        if (![self.downloadProgressTimer isValid])
        {
            self.downloadProgressTimer = [NSTimer scheduledTimerWithTimeInterval:0.5
                                                                          target:self
                                                                        selector:@selector(updateDownloadProgressView:)
                                                                        userInfo:sessionTask
                                                                         repeats:YES];
        }
    }
    else
    {
        [self.summaryLabel setHidden:NO];
        [self.playedStatusImageView setHidden:NO];
        [self.pubDateAndTimeLeftLabel setHidden:NO];
        [self.showNotesButton setHidden:NO];
        [self.downloadProgressView setHidden:YES];
        [self.downloadSizeProgressLabel setHidden:YES];
        [self.downloadButton setHidden:YES];
        
        if ([self.downloadProgressTimer isValid])
        {
            [self.downloadProgressTimer invalidate];
        }
    }
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGEpisodeDownloadStatus)downloadStatus
{
    if (downloadStatus == IGEpisodeDownloadStatusDownloaded)
    {
        [self.episodeDownloadedImageView setHidden:NO];
    }
    else
    {
        [self.episodeDownloadedImageView setHidden:YES];
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

#pragma mark - Update Download Progress

- (void)updateDownloadProgressView:(id)sender
{
    NSURLSessionDownloadTask *sessionTask = (NSURLSessionDownloadTask *)[sender userInfo];
    if (sessionTask.countOfBytesReceived == 0)
    {
        return;
    }
    
    self.downloadProgressView.progress = (double)sessionTask.countOfBytesReceived / (double)sessionTask.countOfBytesExpectedToReceive;
    
    NSString *bytesReceived = [NSByteCountFormatter stringFromByteCount:sessionTask.countOfBytesReceived
                                                             countStyle:NSByteCountFormatterCountStyleDecimal];
    NSString *bytesExpectedToReceive = [NSByteCountFormatter stringFromByteCount:sessionTask.countOfBytesExpectedToReceive
                                                                      countStyle:NSByteCountFormatterCountStyleBinary];
    [self.downloadSizeProgressLabel setText:[NSString stringWithFormat:NSLocalizedString(@"EpisodeDownloadProgress", nil), bytesReceived, bytesExpectedToReceive]];
}

#pragma mark - 

- (IBAction)pauseOrResumeDownload:(id)sender
{
    NSURLSessionDownloadTask *sessionTask = [IGNetworkManager downloadTaskForURL:self.downloadURL];
    if (sessionTask.state == NSURLSessionTaskStateRunning)
    {
        [sessionTask suspend];
        
        [self updateDownloadButtonImageForSessionState:NSURLSessionTaskStateSuspended];
    }
    else
    {
        [sessionTask resume];
        
        [self updateDownloadButtonImageForSessionState:NSURLSessionTaskStateRunning];
    }
}

- (void)updateDownloadButtonImageForSessionState:(NSURLSessionTaskState)state
{
    if (state == NSURLSessionTaskStateRunning)
    {
        [self.downloadButton setImage:[UIImage imageNamed:@"download-pause-button"]
                             forState:UIControlStateNormal];
        [self.downloadButton setAccessibilityLabel:NSLocalizedString(@"PauseDownload", nil)];
    }
    else
    {
        [self.downloadButton setImage:[UIImage imageNamed:@"download-resume-button"]
                             forState:UIControlStateNormal];
        [self.downloadButton setAccessibilityLabel:NSLocalizedString(@"ResumeDownload", nil)];
    }
}

@end
