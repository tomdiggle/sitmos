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

#import "IGEpisodeShowNotesHeader.h"

#import "NSDate+Helper.h"
#import "IGDefines.h"

@interface IGEpisodeShowNotesHeader ()

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *pubDateAndDurationLabel;
@property (nonatomic, strong) UIImageView *playedStatusImageView;
@property (nonatomic, strong) UIImageView *downloadStatusImageView;

@end

@implementation IGEpisodeShowNotesHeader

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    
    [self setBackgroundColor:kRGBA(245, 245, 245, 1)];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10.f, 10.f, 200.f, 18.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont boldSystemFontOfSize:18.f]];
    _titleLabel = label;
    [self addSubview:_titleLabel];
    
    label = [[UILabel alloc] initWithFrame:CGRectZero];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:12.f]];
    _pubDateAndDurationLabel = label;
    [self addSubview:_pubDateAndDurationLabel];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(10.f, 37.f, 9.f, 9.f)];
    _playedStatusImageView = imageView;
    [self addSubview:_playedStatusImageView];
    
    imageView = [[UIImageView alloc] initWithFrame:CGRectMake(frame.size.width - 20.f, 0, 20.f, 20.f)];
    [imageView setImage:[UIImage imageNamed:@"episode-downloaded-icon"]];
    [imageView setHidden:YES];
    _downloadStatusImageView = imageView;
    [self addSubview:_downloadStatusImageView];
    
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(10.f, frame.size.height - 1.f, frame.size.width - 20.f, 1.0f)];
    [divider setBackgroundColor:kRGBA(131, 177, 207, 1)];
    [self addSubview:divider];
    
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    UIImage *image = (_playedStatus == IGEpisodePlayedStatusUnplayed) ? [UIImage imageNamed:@"episode-unplayed-icon"] : (_playedStatus == IGEpisodePlayedStatusHalfPlayed) ? [UIImage imageNamed:@"episode-half-played-icon"] : nil;
    [_playedStatusImageView setImage:image];
    
    _downloadStatus == IGEpisodeDownloadStatusDownloaded ? [_downloadStatusImageView setHidden:NO] : [_downloadStatusImageView setHidden:YES];
    
    CGRect rect = (_playedStatus == IGEpisodePlayedStatusUnplayed || _playedStatus == IGEpisodePlayedStatusHalfPlayed) ? CGRectMake(22.f, 36.f, 150.f, 12.f) : CGRectMake(10.f, 36.f, 150.f, 12.f);
    [_pubDateAndDurationLabel setFrame:rect];
}

#pragma mark - Setters

- (void)setTitle:(NSString *)title
{
    if ([title isEqualToString:_title]) return;
    
    _title = title;
    
    [_titleLabel setText:title];
}

- (void)setPubDate:(NSDate *)pubDate
{
    if ([pubDate isEqualToDate:_pubDate]) return;
    
    _pubDate = pubDate;
    
    [_pubDateAndDurationLabel setText:[NSString stringWithFormat:@"%@ - %@", [NSDate stringFromDate:pubDate withFormat:@"dd MMM yyyy"], _duration]];
}

- (void)setDuration:(NSString *)duration
{
    if ([duration isEqualToString:_duration]) return;
    
    _duration = duration;
    
    [_pubDateAndDurationLabel setText:[NSString stringWithFormat:@"%@ - %@", [NSDate stringFromDate:_pubDate withFormat:@"dd MMM yyyy"], duration]];
}

@end
