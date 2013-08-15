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
#import "IGDefines.h"
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
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(15.f, 4.f, 200.f, 22.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont boldSystemFontOfSize:14.f]];
    _titleLabel = label;
    [self addSubview:_titleLabel];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(15.f, 20.f, 266.f, 40.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:11.f]];
    [label setLineBreakMode:NSLineBreakByWordWrapping | NSLineBreakByTruncatingTail];
    [label setNumberOfLines:2];
    _summaryLabel = label;
    [self addSubview:_summaryLabel];
    
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:11.f]];
    [label setTextColor:kRGBA(179, 179, 179, 1)];
    _pubDateAndTimeLeftLabel = label;
    [self addSubview:_pubDateAndTimeLeftLabel];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(15.f, 52.f, 140.f, 14.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setText:NSLocalizedString(@"Loading", @"text label for loading")];
    [label setFont:[UIFont systemFontOfSize:11.f]];
    [label setTextColor:kRGBA(179, 179, 179, 1)];
    [label setAccessibilityElementsHidden:YES];
    [label setHidden:YES];
    _downloadSizeProgressLabel = label;
    [self addSubview:_downloadSizeProgressLabel];
    
    UIButton *button = [[UIButton alloc] initWithFrame:CGRectMake(280.f, 0, 40.f, 78.f)];
    [button setImage:[UIImage imageNamed:@"more-info-button"] forState:UIControlStateNormal];
    [button setAccessibilityLabel:NSLocalizedString(@"MoreInfo", @"accessibility label for more info")];
    [button setAccessibilityHint:NSLocalizedString(@"ViewMoreInfo", @"accessibility hint for view more info")];
    _moreInfoButton = button;
    [self addSubview:_moreInfoButton];
    
    button = [[UIButton alloc] initWithFrame:CGRectMake(280.f, 0, 40.f, 78.f)];
    [button setHidden:YES];
    _downloadButton = button;
    [self addSubview:_downloadButton];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(15.f, 58.f, 9.f, 9.f)];
    _playedStatusImageView = imageView;
    [self addSubview:_playedStatusImageView];
    
    imageView = [[UIImageView alloc] initWithFrame:CGRectMake(self.bounds.size.width - 20.f, 0, 20.f, 20.f)];
    [imageView setImage:[UIImage imageNamed:@"episode-downloaded-icon"]];
    [imageView setHidden:YES];
    _episodeDownloadedImageView = imageView;
    [self addSubview:_episodeDownloadedImageView];
    
    UIProgressView *progressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    [progressView setFrame:CGRectMake(15.f, 35.f, 260.f, 12.f)];
    [progressView setTrackImage:[[UIImage imageNamed:@"download-episode-track-image"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 8.f, 0, 8.f)]];
    [progressView setProgressImage:[[UIImage imageNamed:@"download-episode-progress-image"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 8.f, 0, 8.f)]];
    [progressView setHidden:YES];
    _downloadProgressView = progressView;
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
            [_titleLabel setTextColor:kRGBA(41, 41, 41, 1)];
            [_titleLabel setHighlightedTextColor:kRGBA(41, 41, 41, 1)];
            
            [_downloadProgressView setHidden:NO];
            [_downloadSizeProgressLabel setHidden:NO];
            [_downloadButton setHidden:NO];
            [_summaryLabel setHidden:YES];
            [_playedStatusImageView setHidden:YES];
            [_pubDateAndTimeLeftLabel setHidden:YES];
            [_moreInfoButton setHidden:YES];
            
            if ([operation isPaused])
            {
                [_downloadButton setImage:[UIImage imageNamed:@"download-episode-resume-button"]
                                 forState:UIControlStateNormal];
                [_downloadButton setAccessibilityLabel:NSLocalizedString(@"ResumeDownload", @"accessibility label for resume download")];
            }
            else
            {
                [_downloadButton setImage:[UIImage imageNamed:@"download-episode-pause-button"]
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
        UIColor *color = _playedStatus == IGEpisodePlayedStatusPlayed ? kRGBA(179, 179, 179, 1) : kRGBA(41, 41, 41, 1);
        [_titleLabel setTextColor:color];
        [_titleLabel setHighlightedTextColor:color];
        [_summaryLabel setTextColor:color];
        [_summaryLabel setHighlightedTextColor:color];
        
        [_summaryLabel setHidden:NO];
        [_playedStatusImageView setHidden:NO];
        [_pubDateAndTimeLeftLabel setHidden:NO];
        [_moreInfoButton setHidden:NO];
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
        
        UIImage *image = (_playedStatus == IGEpisodePlayedStatusUnplayed) ? [UIImage imageNamed:@"episode-unplayed-icon"] : (_playedStatus == IGEpisodePlayedStatusHalfPlayed) ? [UIImage imageNamed:@"episode-half-played-icon"] : nil;
        [_playedStatusImageView setImage:image];
        
        CGRect rect = (_playedStatus == IGEpisodePlayedStatusUnplayed || _playedStatus == IGEpisodePlayedStatusHalfPlayed) ? CGRectMake(28.f, 53.f, 200.f, 22.f) : CGRectMake(15.f, 53.f, 200.f, 22.f);
        [_pubDateAndTimeLeftLabel setFrame:rect];
    }
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGEpisodeDownloadStatus)downloadStatus
{
//    if (downloadStatus == _downloadStatus) return;
    
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

@end
