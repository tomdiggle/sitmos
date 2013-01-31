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

#import <QuartzCore/QuartzCore.h>

#import "IGEpisodeMoreInfoViewController.h"
#import "IGEpisode.h"

@interface IGEpisodeMoreInfoViewController ()

@property (strong, nonatomic) IBOutlet UILabel *episodePublishedLabel;
@property (strong, nonatomic) IBOutlet UILabel *episodeDurationLabel;
@property (strong, nonatomic) IBOutlet UILabel *episodeTypeLabel;
@property (strong, nonatomic) IBOutlet UILabel *episodeSizeLabel;
@property (strong, nonatomic) IBOutlet UIButton *playButton;
@property (strong, nonatomic) IBOutlet UITextView *summaryTextView;
@property (strong, nonatomic) IBOutlet UIImageView *playedStatusImageView;

@end

@implementation IGEpisodeMoreInfoViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.view.layer.cornerRadius = 5.0f;
    self.view.layer.masksToBounds = YES;
    self.view.backgroundColor = kRGBA(245, 245, 245, 1);
    
    [_episodeTitleLabel setText:[_episode title]];
    [_episodePublishedLabel setText:[NSDate stringFromDate:[_episode pubDate] withFormat:@"dd MMM yyyy"]];
    [_episodeDurationLabel setText:[_episode duration]];
    [_episode isAudio] ? [_episodeTypeLabel setText:NSLocalizedString(@"Audio", @"text label for audio")] : [_episodeTypeLabel setText:NSLocalizedString(@"Video", @"text label for video")];
    [_episodeSizeLabel setText:[_episode readableFileSize]];
    [_summaryTextView setText:[_episode summary]];
    
    [_playButton setBackgroundImage:[[UIImage imageNamed:@"more-info-play-button"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10.0f, 0, 10.0f)]
                           forState:UIControlStateNormal];
    
    if (![_episode isCompletelyDownloaded])
    {
        [_playButton setTitle:NSLocalizedString(@"Stream", @"text label for stream")
                     forState:UIControlStateNormal];
    }
    else if (![_episode isPlayed] || [[_episode progress] integerValue] > 0)
    {
        [_playButton setTitle:NSLocalizedString(@"Continue", @"text label for continue")
                     forState:UIControlStateNormal];
    }
    else
    {
        [_playButton setTitle:NSLocalizedString(@"Play", @"text label for play")
                     forState:UIControlStateNormal];
    }
    
    UIView *dividierView = [[UIView alloc] initWithFrame:CGRectMake(6.0f, 72.0f, 288.0f, 2.0f)];
    [dividierView setBackgroundColor:kRGBA(77, 150, 227, 1)];
    [[self view] addSubview:dividierView];
}

- (void)viewDidLayoutSubviews
{
    if (![_episode isPlayed] && [[_episode progress] integerValue] > 0)
    {
        [_playedStatusImageView setImage:[UIImage imageNamed:@"half-played-icon"]];
    }
    else if (![_episode isPlayed])
    {
        [_playedStatusImageView setImage:[UIImage imageNamed:@"unplayed-icon"]];
    }
    else
    {
        [_episodeTitleLabel setFrame:CGRectMake(6.0f, 6.0f, 140.0f, 21.0f)];
    }
}

@end
