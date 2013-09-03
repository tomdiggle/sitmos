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

#import "IGAudioPlayerViewController.h"

#import "IGMediaPlayer.h"
#import "IGMediaPlayerAsset.h"
#import "IGDefines.h"
#import "TDNotificationPanel.h"

@interface IGAudioPlayerViewController ()

@property (nonatomic, weak) IBOutlet UILabel *currentTime;
@property (nonatomic, weak) IBOutlet UILabel *duration;
@property (nonatomic, weak) IBOutlet UISlider *progressSlider;
@property (nonatomic, weak) IBOutlet UIActivityIndicatorView *bufferingIndicator;
@property (nonatomic, weak) IBOutlet UIButton *playButton;
@property (nonatomic, weak) IBOutlet UIButton *seekBackwardButton;
@property (nonatomic, weak) IBOutlet UIButton *seekForwardButton;
@property (nonatomic, strong) NSTimer *playbackProgressUpdateTimer;
@property (nonatomic, strong) IGMediaPlayer *mediaPlayer;

@end

@implementation IGAudioPlayerViewController

#pragma mark - Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Initializers

- (id)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder])) return nil;
    
    [self observeNotifications];
    
    return self;
}

#pragma mark - Setup

- (void)observeNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackStateChanged:)
                                                 name:IGMediaPlayerPlaybackStatusChangedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackEnded:)
                                                 name:IGMediaPlayerPlaybackEndedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playbackFailed:)
                                                 name:IGMediaPlayerPlaybackFailedNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(showBufferingIndicator)
                                                 name:IGMediaPlayerPlaybackBufferEmptyNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(hideBufferingIndicator)
                                                 name:IGMediaPlayerPlaybackLikelyToKeepUpNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
}

#pragma mark - State Preservation and Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    
    [self setTitle:[[self.mediaPlayer asset] title]];
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.mediaPlayer = [IGMediaPlayer sharedInstance];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"media-player-hide-button"]
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(hideAudioPlayer:)];
    
    [self updatePlayButton];
    
    [self.progressSlider setThumbImage:[UIImage imageNamed:@"progress-slider-thumb"] forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self startPlaybackProgressUpdateTimer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self stopPlaybackProgressUpdateTimer];
}

#pragma mark - Orientation Support

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Update UI

- (void)updatePlayButton
{
    if ([_mediaPlayer playbackState] == IGMediaPlayerPlaybackStatePlaying)
	{
        [_playButton setImage:[UIImage imageNamed:@"pause-button"] forState:UIControlStateNormal];
        [_playButton setAccessibilityLabel:NSLocalizedString(@"Pause", @"accessibility label for pause")];
        [_playButton setAccessibilityHint:NSLocalizedString(@"PausesEpisode", @"accessibility hint for pauses episode")];
	}
	else
	{
        [_playButton setImage:[UIImage imageNamed:@"play-button"] forState:UIControlStateNormal];
        [_playButton setAccessibilityLabel:NSLocalizedString(@"Play", @"accessibility label for play")];
        [_playButton setAccessibilityHint:NSLocalizedString(@"PlaysEpisode", @"accessibility hint for plays episode")];
	}
}

- (void)updatePlaybackProgress
{
    if ([_mediaPlayer duration] <= 0) return;
    
    [_currentTime setText:[self currentTimeString]];
    [_duration setText:[self durationString]];
    [_progressSlider setMaximumValue:[_mediaPlayer duration]];
    [_progressSlider setValue:[_mediaPlayer currentTime]];
}

- (void)showBufferingIndicator
{
    [_bufferingIndicator startAnimating];
    [_currentTime setHidden:YES];
}

- (void)hideBufferingIndicator
{
    if (![_bufferingIndicator isAnimating]) return;
    
    [_bufferingIndicator stopAnimating];
    [_currentTime setHidden:NO];
}

#pragma mark - Hide Audio Player

- (void)hideAudioPlayer:(id)sender
{
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

#pragma mark - Playback

- (IBAction)playButtonTapped:(id)sender
{
    if ([_mediaPlayer playbackState] == IGMediaPlayerPlaybackStatePaused)
	{
        [self play];
    }
    else
    {
        [self pause];
    }
}

- (void)play
{
    [self startPlaybackProgressUpdateTimer];
    [_mediaPlayer play];
    [self updatePlayButton];
}

- (void)pause
{
    [self stopPlaybackProgressUpdateTimer];
    [_mediaPlayer pause];
    [self updatePlayButton];
}

- (IBAction)seekForward:(id)sender
{
    if ([sender isKindOfClass:[UILongPressGestureRecognizer class]])
    {
        if ([sender state] == UIGestureRecognizerStateBegan)
        {
            [_mediaPlayer beginSeekingForward];
        }
        else if ([sender state] == UIGestureRecognizerStateEnded)
        {
            if ([_mediaPlayer playbackState] == IGMediaPlayerPlaybackStateSeekingForward)
            {
                [_mediaPlayer endSeeking];
            }
        }
    }
    else
    {
        NSUInteger skipForwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingForwardTime];
        [_mediaPlayer seekToTime:[_mediaPlayer currentTime] + (float)skipForwardTime];
    }
}

- (IBAction)seekBackward:(id)sender
{
    if ([sender isKindOfClass:[UILongPressGestureRecognizer class]])
    {
        if ([sender state] == UIGestureRecognizerStateBegan)
        {
            [_mediaPlayer beginSeekingBackward];
        }
        else if ([sender state] == UIGestureRecognizerStateEnded)
        {
            if ([_mediaPlayer playbackState] == IGMediaPlayerPlaybackStateSeekingBackward)
            {
                [_mediaPlayer endSeeking];
            }
        }
    }
    else
    {
        NSUInteger skipBackwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingBackwardTime];
        [_mediaPlayer seekToTime:[_mediaPlayer currentTime] - (float)skipBackwardTime];
    }
}

#pragma mark - Timing

/**
 * Invoked when the progress slider is dragged.
 *
 * @param slider The progress slider.
 */
- (IBAction)seekToTime:(UISlider *)slider
{
    Float64 newSeekTime = [slider value];
    [_mediaPlayer seekToTime:newSeekTime];
    
    [_currentTime setText:[self currentTimeString]];
    [_duration setText:[self durationString]];
}

/**
 * Invoked when the progress slider is touched down.
 *
 * @param slider The progress slider.
 */
- (IBAction)seekToTimeStart:(UISlider *)slider
{
    [self stopPlaybackProgressUpdateTimer];
}

/**
 * Invoked when the progress slider touched up.
 *
 * @param slider The progress slider.
 */
- (IBAction)seekToTimeStop:(UISlider *)slider
{
    [self startPlaybackProgressUpdateTimer];
    [self play];
}

- (NSString *)currentTimeString
{
    Float64 currentTime = [_mediaPlayer currentTime];
    
    NSInteger secondsPlayed = (NSInteger)currentTime % 60;
    NSInteger minutesPlayed = (NSInteger)currentTime / 60 % 60;
    NSInteger hoursPlayed = ((NSInteger)currentTime / 60) / 60;
    
    return hoursPlayed > 0 ? [NSString stringWithFormat:@"%2d:%02d:%02d", hoursPlayed, minutesPlayed, secondsPlayed] : [NSString stringWithFormat:@"%2d:%02d", minutesPlayed, secondsPlayed];
}

- (NSString *)durationString
{
    Float64 currentTime = [_mediaPlayer currentTime];
    Float64 duration = [_mediaPlayer duration];
    
    NSInteger secondsLeft = ((NSInteger)duration - (NSInteger)currentTime) % 60;
    NSInteger minutesLeft = ((NSInteger)duration - (NSInteger)currentTime) / 60 % 60;
    NSInteger hoursLeft = (((NSInteger)duration - (NSInteger)currentTime) / 60) / 60;
    
    return hoursLeft > 0 ? [NSString stringWithFormat:@"-%2d:%02d:%02d", hoursLeft, minutesLeft, secondsLeft] : [NSString stringWithFormat:@"-%1d:%02d", minutesLeft, secondsLeft];
}

#pragma mark - Playback Progress

- (void)startPlaybackProgressUpdateTimer
{
    if ([_playbackProgressUpdateTimer isValid]) return;
    
    _playbackProgressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                                    target:self
                                                                  selector:@selector(updatePlaybackProgress)
                                                                  userInfo:nil
                                                                   repeats:YES];
}

- (void)stopPlaybackProgressUpdateTimer
{
    if (![_playbackProgressUpdateTimer isValid]) return;
    
    [_playbackProgressUpdateTimer invalidate];
}

#pragma mark - Media Player Notification Observer Methods

- (void)playbackEnded:(NSNotification *)notification
{
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (void)playbackFailed:(NSNotification *)notification
{
    [TDNotificationPanel showNotificationInView:self.view.window
                                          title:NSLocalizedString(@"EpisodePlaybackFailed", "text label for episode playback failed")
                                       subtitle:nil
                                           type:TDNotificationTypeError
                                           mode:TDNotificationModeText
                                    dismissable:YES
                                 hideAfterDelay:4];
    
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

- (void)playbackStateChanged:(NSNotification *)notification
{
    if ([_mediaPlayer playbackState] == IGMediaPlayerPlaybackStatePlaying || [_mediaPlayer playbackState] == IGMediaPlayerPlaybackStatePaused)
    {
        [self hideBufferingIndicator];
        [self updatePlayButton];
    }
    else if ([_mediaPlayer playbackState] == IGMediaPlayerPlaybackStateBuffering)
    {
        [self showBufferingIndicator];
    }
}

#pragma mark - UIApplication Notification Observer Methods 

- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self stopPlaybackProgressUpdateTimer];
}

- (void)applicationDidEnterForeground:(NSNotification *)notification
{
    [self startPlaybackProgressUpdateTimer];
}

@end
