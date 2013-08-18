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

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *summaryLabel;
@property (nonatomic, strong) UILabel *pubDateAndTimeLeftLabel;
@property (nonatomic, strong) UILabel *downloadSizeProgressLabel;
@property (nonatomic, strong) UIImageView *playedStatusImageView;
@property (nonatomic, strong) UIImageView *episodeDownloadedImageView;
@property (nonatomic, strong) UIProgressView *downloadProgressView;

@end

@implementation IGEpisodeCell

#pragma mark - Initializers

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) return nil;
    
    _titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.f, 4.f, 200.f, 22.f)];
    [_titleLabel setBackgroundColor:[UIColor clearColor]];
    [_titleLabel setFont:[UIFont boldSystemFontOfSize:14.f]];
    [_titleLabel setHighlightedTextColor:[UIColor whiteColor]];
    [self addSubview:_titleLabel];
    
    _summaryLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.f, 20.f, 266.f, 40.f)];
    [_summaryLabel setBackgroundColor:[UIColor clearColor]];
    [_summaryLabel setFont:[UIFont systemFontOfSize:12.f]];
    [_summaryLabel setTextColor:[self playedColor]];
    [_summaryLabel setHighlightedTextColor:[UIColor whiteColor]];
    [_summaryLabel setLineBreakMode:NSLineBreakByWordWrapping | NSLineBreakByTruncatingTail];
    [_summaryLabel setNumberOfLines:2];
    [self addSubview:_summaryLabel];
    
    _pubDateAndTimeLeftLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    [_pubDateAndTimeLeftLabel setBackgroundColor:[UIColor clearColor]];
    [_pubDateAndTimeLeftLabel setFont:[UIFont systemFontOfSize:11.f]];
    [_pubDateAndTimeLeftLabel setTextColor:[self playedColor]];
    [_pubDateAndTimeLeftLabel setHighlightedTextColor:[UIColor whiteColor]];
    [self addSubview:_pubDateAndTimeLeftLabel];
    
    _downloadSizeProgressLabel = [[UILabel alloc] initWithFrame:CGRectMake(15.f, 52.f, 140.f, 14.f)];
    [_downloadSizeProgressLabel setBackgroundColor:[UIColor clearColor]];
    [_downloadSizeProgressLabel setText:NSLocalizedString(@"Loading", @"text label for loading")];
    [_downloadSizeProgressLabel setFont:[UIFont systemFontOfSize:11.f]];
    [_downloadSizeProgressLabel setHighlightedTextColor:[UIColor whiteColor]];
    [_downloadSizeProgressLabel setTextColor:[self playedColor]];
    [_downloadSizeProgressLabel setAccessibilityElementsHidden:YES];
    [_downloadSizeProgressLabel setHidden:YES];
    [self addSubview:_downloadSizeProgressLabel];
    
    _showNotesButton = [[UIButton alloc] initWithFrame:CGRectMake(280.f, 0, 40.f, 78.f)];
    [_showNotesButton setImage:[UIImage imageNamed:@"more-info-button"] forState:UIControlStateNormal];
    [_showNotesButton setAccessibilityLabel:NSLocalizedString(@"EpisodeShowNotes", @"accessibility label for episode show notes")];
    [_showNotesButton setAccessibilityHint:NSLocalizedString(@"ViewEpisodeShowNotes", @"accessibility hint for view episode show notes")];
    [self addSubview:_showNotesButton];
    
    _downloadButton = [[UIButton alloc] initWithFrame:CGRectMake(280.f, 0, 40.f, 78.f)];
    [_downloadButton setHidden:YES];
    [self addSubview:_downloadButton];
    
    _playedStatusImageView = [[UIImageView alloc] initWithFrame:CGRectMake(15.f, 60.f, 8.f, 8.f)];
    [self addSubview:_playedStatusImageView];
    
    _episodeDownloadedImageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.bounds.size.width - 21.f, 0, 21.f, 22.f)];
    [_episodeDownloadedImageView setImage:[UIImage imageNamed:@"episode-downloaded-icon"]];
    [_episodeDownloadedImageView setHidden:YES];
    [self addSubview:_episodeDownloadedImageView];
    
    _downloadProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [_downloadProgressView setFrame:CGRectMake(15.f, 40.f, 260.f, 12.f)];
    [_downloadProgressView setProgressTintColor:[UIColor colorWithRed:0.329 green:0.643 blue:0.901 alpha:1]];
    [_downloadProgressView setHidden:YES];
    [self addSubview:_downloadProgressView];
    
    return self;
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
        UIColor *color = nil;
        if (_playedStatus == IGEpisodePlayedStatusPlayed)
        {
            color = [self playedColor];
        }
        else
        {
            color = [self unplayedColor];
        }
        [_titleLabel setTextColor:color];
        
        [_summaryLabel setHidden:NO];
        [_playedStatusImageView setHidden:NO];
        [_pubDateAndTimeLeftLabel setHidden:NO];
        [_showNotesButton setHidden:NO];
        [_downloadProgressView setHidden:YES];
        [_downloadSizeProgressLabel setHidden:YES];
        [_downloadButton setHidden:YES];
        
        if (_downloadStatus == IGEpisodeDownloadStatusDownloaded)
        {
            [_episodeDownloadedImageView setHidden:NO];
        }
        else
        {
            [_episodeDownloadedImageView setHidden:YES];
        }
        
        UIImage *image = nil;
        if (_playedStatus == IGEpisodePlayedStatusUnplayed)
        {
            image = [UIImage imageNamed:@"episode-unplayed-icon"];
        }
        else if (_playedStatus == IGEpisodePlayedStatusHalfPlayed)
        {
            image = [UIImage imageNamed:@"episode-half-played-icon"];
        }
        [_playedStatusImageView setImage:image];
        
        CGRect rect = CGRectZero;
        if (_playedStatus == IGEpisodePlayedStatusUnplayed || _playedStatus == IGEpisodePlayedStatusHalfPlayed)
        {
            rect = CGRectMake(28.f, 53.f, 200.f, 22.f);
        }
        else
        {
            rect = CGRectMake(15.f, 53.f, 200.f, 22.f);
        }
        [_pubDateAndTimeLeftLabel setFrame:rect];
    }
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGEpisodeDownloadStatus)downloadStatus
{  
    _downloadStatus = downloadStatus;
    
    [self setNeedsLayout];
}

- (void)setPlayedStatus:(IGEpisodePlayedStatus)playedStatus
{
    if (playedStatus == _playedStatus) return;
    
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
