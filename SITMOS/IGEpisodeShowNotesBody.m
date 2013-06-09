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

#import "IGEpisodeShowNotesBody.h"

#import "NSDate+Helper.h"

@interface IGEpisodeShowNotesBody ()

@property (nonatomic, strong) UILabel *pubDateLabel;
@property (nonatomic, strong) UILabel *durationLabel;
@property (nonatomic, strong) UILabel *mediaTypeLabel;
@property (nonatomic, strong) UILabel *fileSizeLabel;
@property (nonatomic, strong) UITextView *summaryTextView;

@end

@implementation IGEpisodeShowNotesBody

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    
    // Published
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(10.f, 10.f, 70.f, 16.f)];
    [label setText:NSLocalizedString(@"Published", @"text label for published")];
    [label setTextAlignment:NSTextAlignmentRight];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont boldSystemFontOfSize:12.f]];
    [self addSubview:label];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(84.f, 10.f, 80.f, 16.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:12.f]];
    _pubDateLabel = label;
    [self addSubview:_pubDateLabel];
    
    // Duration
    label = [[UILabel alloc] initWithFrame:CGRectMake(10.f, 30.f, 70.f, 16.f)];
    [label setText:NSLocalizedString(@"Duration", @"text label for duration")];
    [label setTextAlignment:NSTextAlignmentRight];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont boldSystemFontOfSize:12.f]];
    [self addSubview:label];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(84.f, 30.f, 80.f, 16.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:12.f]];
    _durationLabel = label;
    [self addSubview:_durationLabel];
    
    // Type
    label = [[UILabel alloc] initWithFrame:CGRectMake(170.f, 10.f, 40.f, 16.f)];
    [label setText:NSLocalizedString(@"Type", @"text label for type")];
    [label setTextAlignment:NSTextAlignmentRight];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont boldSystemFontOfSize:12.f]];
    [self addSubview:label];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(214.f, 10.f, 80.f, 16.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:12.f]];
    _mediaTypeLabel = label;
    [self addSubview:_mediaTypeLabel];
    
    // Size
    label = [[UILabel alloc] initWithFrame:CGRectMake(170.f, 30.f, 40.f, 16.f)];
    [label setText:NSLocalizedString(@"Size", @"text label for size")];
    [label setTextAlignment:NSTextAlignmentRight];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont boldSystemFontOfSize:12.f]];
    [self addSubview:label];
    
    label = [[UILabel alloc] initWithFrame:CGRectMake(214.f, 30.f, 80.f, 16.f)];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setFont:[UIFont systemFontOfSize:12.f]];
    _fileSizeLabel = label;
    [self addSubview:_fileSizeLabel];
    
    // Summary
    UITextView *textView = [[UITextView alloc] initWithFrame:CGRectZero];
    [textView setContentInset:UIEdgeInsetsMake(0, -8.f, 0, -8.f)];
    [textView setBackgroundColor:[UIColor clearColor]];
    [textView setFont:[UIFont systemFontOfSize:12.f]];
    [textView setEditable:NO];
    _summaryTextView = textView;
    [self addSubview:_summaryTextView];
    
    return self;
}

#pragma mark - Setters

- (void)setPubDate:(NSDate *)pubDate
{
    if ([pubDate isEqualToDate:_pubDate]) return;
    
    _pubDate = pubDate;
    
    [_pubDateLabel setText:[NSDate stringFromDate:pubDate withFormat:@"dd MMM yyyy"]];
}

- (void)setDuration:(NSString *)duration
{
    if ([duration isEqualToString:_duration]) return;
    
    _duration = duration;
    
    [_durationLabel setText:duration];
}

- (void)setAudio:(BOOL)audio
{
    _audio = audio;
    
    NSString *mediaType = audio ? NSLocalizedString(@"Audio", @"text label for audio") : NSLocalizedString(@"Video", @"text label for video");
    [_mediaTypeLabel setText:mediaType];
}

- (void)setFileSize:(NSString *)fileSize
{
    if ([fileSize isEqualToString:_fileSize]) return;
    
    _fileSize = fileSize;
    
    [_fileSizeLabel setText:fileSize];
}

- (void)setSummary:(NSString *)summary
{
    if ([summary isEqualToString:_summary]) return;
    
    _summary = summary;
    
    // The width of the constrainedToSize: CGSize is 20 smaller than the actual width to account for margin/padding otherwise the last part of the summary gets clipped
    CGSize summaryTextViewSize = [summary sizeWithFont:_summaryTextView.font
                                     constrainedToSize:CGSizeMake(280.f, FLT_MAX)];
    [_summaryTextView setFrame:CGRectMake(10.f, 52.f, 300.f, summaryTextViewSize.height)];
    [_summaryTextView setText:summary];
}

@end
