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

#import <MediaPlayer/MediaPlayer.h>

#import "IGAudioPlayerViewController.h"
#import "TDSlider.h"
#import "RIButtonItem.h"
#import "UIAlertView+Blocks.h"
#import "UIActionSheet+Blocks.h"
#import "MBProgressHUD.h"

@interface IGAudioPlayerViewController ()

@property (strong, nonatomic) IBOutlet UIView *upperPlayerControls;
@property (strong, nonatomic) IBOutlet UILabel *currentTimeLabel;
@property (strong, nonatomic) IBOutlet UILabel *durationLabel;
@property (strong, nonatomic) IBOutlet TDSlider *progressSlider;
@property (strong, nonatomic) IBOutlet UIButton *playbackSpeedButton;
@property (strong, nonatomic) IBOutlet UILabel *skippingBackLabel;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIView *lowerPlayerControls;
@property (strong, nonatomic) IBOutlet UIButton *playButton;
@property (strong, nonatomic) IBOutlet MPVolumeView *volumeSlider;
@property (strong, nonatomic) IGMediaPlayer *mediaPlayer;
@property (strong, nonatomic) NSTimer *playbackProgressUpdateTimer;
@property (strong, nonatomic) MBProgressHUD *bufferingHUD;

@end

@implementation IGAudioPlayerViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _mediaPlayer = [IGMediaPlayer sharedInstance];
    
    [self applyStylesheet]; 
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackEnded:)
                                                     name:IGMediaPlayerPlaybackEndedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackFailed:)
                                                     name:IGMediaPlayerPlaybackFailedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackStateChanged:)
                                                     name:IGMediaPlayerPlaybackStatusChangedNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(showBufferingHUD)
                                                     name:IGMediaPlayerPlaybackBufferEmptyNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(hideBufferingHUD)
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
    });
    
    UISwipeGestureRecognizer *rightRecognizer = [[UISwipeGestureRecognizer alloc] initWithTarget:self
                                                                                          action:@selector(swipeRight:)];
    [rightRecognizer setNumberOfTouchesRequired:1];
    [rightRecognizer setDirection:UISwipeGestureRecognizerDirectionRight];
    [_backgroundImageView addGestureRecognizer:rightRecognizer];
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

#pragma mark - Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IGMediaPlayerPlaybackEndedNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IGMediaPlayerPlaybackFailedNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IGMediaPlayerPlaybackStatusChangedNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IGMediaPlayerPlaybackBufferEmptyNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IGMediaPlayerPlaybackLikelyToKeepUpNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidEnterBackgroundNotification
                                                  object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationWillEnterForegroundNotification
                                                  object:nil];
}

#pragma mark - Stylesheet

- (void)applyStylesheet
{
    [_backgroundImageView setImage:[UIImage imageNamed:@"audio-player-bg"]];
    [_upperPlayerControls setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"audio-player-upper-controls-bg"]]];
    [_lowerPlayerControls setBackgroundColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"audio-player-lower-controls-bg"]]];
    [_progressSlider setProgressColor:[UIColor colorWithPatternImage:[UIImage imageNamed:@"progress-slider-fill"]]];
    [_progressSlider setThumbImage:[UIImage imageNamed:@"progress-slider-thumb"] forState:UIControlStateNormal];
    [_currentTimeLabel setFont:[UIFont fontWithName:IGFontNameMedium size:12.0f]];
    [_durationLabel setFont:[UIFont fontWithName:IGFontNameMedium size:12.0f]];
    [_skippingBackLabel setFont:[UIFont fontWithName:IGFontNameRegular size:10.0f]];
}

- (void)updatePlayButtonImage
{
    if ([_mediaPlayer isPaused])
	{
        [_playButton setImage:[UIImage imageNamed:@"play-button"] forState:UIControlStateNormal];
        [_playButton setAccessibilityLabel:NSLocalizedString(@"Play", @"accessibility label for play")];
        [_playButton setAccessibilityHint:NSLocalizedString(@"PlaysEpisode", @"accessibility hint for plays episode")];
	}
	else
	{
        [_playButton setImage:[UIImage imageNamed:@"pause-button"] forState:UIControlStateNormal];
        [_playButton setAccessibilityLabel:NSLocalizedString(@"Pause", @"accessibility label for pause")];
        [_playButton setAccessibilityHint:NSLocalizedString(@"PausesEpisode", @"accessibility hint for pauses episode")];
	}
}

#pragma mark - IBActions

- (IBAction)skippingBackButtonTapped:(id)sender
{
    /*CABasicAnimation *rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat:-M_PI * 2.0];
    rotationAnimation.duration = 0.4f;
    rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [[sender layer] addAnimation:rotationAnimation
                          forKey:@"rotationAnimation"];
    [_mediaPlayer seekToTime:[_mediaPlayer currentTime] - 30.0f];
    
    if ([_mediaPlayer isPaused])
    {
        [self updatePlaybackProgress];
    }*/
}

- (IBAction)playButtonTapped:(id)sender
{
    if ([[_playButton currentImage] isEqual:[UIImage imageNamed:@"play-button"]])
	{
        [self updatePlayButtonImage];
		[self play];
	}
	else
	{
        [self updatePlayButtonImage];
		[self pause];
	}
}

/**
 * Invoked when the next track button is held down for more than 1 second.
 */
- (IBAction)seekForward:(id)sender
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

- (IBAction)skipForwardButtonTapped:(id)sender
{
    NSUInteger skipForwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingForwardTime];
    [_mediaPlayer seekToTime:[_mediaPlayer currentTime] + (float)skipForwardTime];
}

/**
 * Invoked when the previous track button is held down for more than 1 second.
 */
- (IBAction)seekBackward:(id)sender
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

- (IBAction)skipBackwardButtonTapped:(id)sender
{
    NSUInteger skipBackwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingBackwardTime];
    [_mediaPlayer seekToTime:[_mediaPlayer currentTime] - (float)skipBackwardTime];
}

/**
 * Invoked when user moves slider. The time played and time left labels get updated while the slider is moving.
 *
 * @param slider The progress slider.
 */
- (IBAction)seekToTime:(UISlider *)slider
{
    Float64 newSeekTime = [slider value];
    [_mediaPlayer seekToTime:newSeekTime];
    
    [_currentTimeLabel setText:[self currentTimeString]];
    [_durationLabel setText:[self durationString]];
}

/**
 * Invoked when the progress slider is touched down. Stops the playback progress update timer from updating the progress slider while the user is seeking.
 *
 * @param slider The progress slider.
 */
- (IBAction)seekToTimeStart:(UISlider *)slider
{
    [self stopPlaybackProgressUpdateTimer];
}

/**
 * Invoked when the progress slider is touched up. Starts the playback progress update timer so the progress slider can be updated with the current playback progress and restarts playback.
 *
 * @param slider The progress slider.
 */
- (IBAction)seekToTimeStop:(UISlider *)slider
{
    [self startPlaybackProgressUpdateTimer];
    [self play];
}

- (IBAction)shareEpisodeButtonTapped:(id)sender
{
    NSString *shareText = [NSString stringWithFormat:@"%@ %@ %@ Stuck in the Middle of Somewhere http://sitmos.net/audio.php", NSLocalizedString(@"CheckOut", "text label for check out"), [self title], NSLocalizedString(@"Of", "text label for of")];
    UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:@[shareText]
                                                                                         applicationActivities:nil];
    activityViewController.excludedActivityTypes = @[UIActivityTypePostToWeibo, UIActivityTypePrint, UIActivityTypeAssignToContact, UIActivityTypeSaveToCameraRoll];
    [self presentViewController:activityViewController
                       animated:YES
                     completion:nil];
}

- (IBAction)playbackSpeedButtonTapped:(id)sender
{
    if ([sender class] != [UIButton class]) return;
    
    if ([[sender imageForState:UIControlStateNormal] isEqual:[UIImage imageNamed:@"playback-speed-2x"]])
    {
        [sender setImage:[UIImage imageNamed:@"playback-speed-1x"] forState:UIControlStateNormal];
        [_mediaPlayer setPlaybackRate:1.0f];
    }
    else if ([[sender imageForState:UIControlStateNormal] isEqual:[UIImage imageNamed:@"playback-speed-1-5x"]])
    {
        [sender setImage:[UIImage imageNamed:@"playback-speed-2x"] forState:UIControlStateNormal];
        [_mediaPlayer setPlaybackRate:2.0f];
    }
    else
    {
        [sender setImage:[UIImage imageNamed:@"playback-speed-1-5x"] forState:UIControlStateNormal];
        [_mediaPlayer setPlaybackRate:1.5f];
    }
}

#pragma mark - Playback Methods

/**
 * Restarts playback of episode, starts the playback progress update timer and changes the play button image to the pause icon.
 */
- (void)play
{
    [self startPlaybackProgressUpdateTimer];
    [_mediaPlayer play];
    [self updatePlayButtonImage];
}

/**
 * Pauses playback of episode, stops the playback progress timer and chanegs the play button image to the play icon.
 */
- (void)pause
{
    [self stopPlaybackProgressUpdateTimer];
    [_mediaPlayer pause];
    [self updatePlayButtonImage];
}

#pragma mark - Timing

/**
 * Returns a formatted NSString of the current time of the current episode.
 *
 * @return A formatted NSString of the current time of the current episode.
 */
- (NSString *)currentTimeString
{
    Float64 currentTime = [_mediaPlayer currentTime];
    
    NSInteger secondsPlayed = (NSInteger)currentTime % 60;
    NSInteger minutesPlayed = (NSInteger)currentTime / 60 % 60;
    NSInteger hoursPlayed = ((NSInteger)currentTime / 60) / 60;
    
    return hoursPlayed > 0 ? [NSString stringWithFormat:@"%2d:%02d:%02d", hoursPlayed, minutesPlayed, secondsPlayed] : [NSString stringWithFormat:@"%2d:%02d", minutesPlayed, secondsPlayed];
}

/**
 * Returns a formatted NSString of the duration of the current episode.
 *
 * @return A formatted NSString of the duration of the current episode.
 */
- (NSString *)durationString
{
    Float64 currentTime = [_mediaPlayer currentTime];
    Float64 duration = [_mediaPlayer duration];
    
    NSInteger secondsLeft = ((NSInteger)duration - (NSInteger)currentTime) % 60;
    NSInteger minutesLeft = ((NSInteger)duration - (NSInteger)currentTime) / 60 % 60;
    NSInteger hoursLeft = (((NSInteger)duration - (NSInteger)currentTime) / 60) / 60;
    
    return hoursLeft > 0 ? [NSString stringWithFormat:@"%2d:%02d:%02d", hoursLeft, minutesLeft, secondsLeft] : [NSString stringWithFormat:@"%2d:%02d", minutesLeft, secondsLeft];
}

#pragma mark - Buffering HUD

/**
 * Shows the buffering hud on the main thread if it's not already being displayed.
 */
- (void)showBufferingHUD
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!_bufferingHUD)
        {
            _bufferingHUD = [[MBProgressHUD alloc] initWithView:[self view]];
            _bufferingHUD.labelText = NSLocalizedString(@"Buffering", @"text label for buffering");
            [[self view] addSubview:_bufferingHUD];
        }
    });
}

/**
 * Hides the buffering hud if it's being displayed.
 */
- (void)hideBufferingHUD
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([_bufferingHUD isHidden]) return;
        
        [_bufferingHUD hide:YES];
    });
}

#pragma mark - Playback Progress Update

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

/**
 * Invoked while audio is playing by the playback progress update timer. Updates the progress slider's progress value and the time played and time left labels.
 */
- (void)updatePlaybackProgress
{
    if ([_mediaPlayer duration] <= 0) return;
    
    [_progressSlider setMaximumValue:[_mediaPlayer duration]];
    [_currentTimeLabel setText:[self currentTimeString]];
    [_durationLabel setText:[self durationString]];
    [_progressSlider setProgress:[_mediaPlayer availableDuration]];
    [_progressSlider setValue:[_mediaPlayer currentTime]];
}

#pragma mark - Swipe Gesture Recognizer 

- (void)swipeRight:(UISwipeGestureRecognizer *)swipeGestureRecognizer
{
    [[self navigationController] popViewControllerAnimated:YES];
}

#pragma mark - Media Player Notification Observer Methods

/**
 * When playback has finsihed pop the view back to the episode lists view controller.
 */
- (void)playbackEnded:(NSNotification *)notification
{
    [[self navigationController] popViewControllerAnimated:YES];
}

/**
 * Invoked when playback fails. Displays an error message to user and will pop the view controller back to the episodes list when OK is tapped.
 */
- (void)playbackFailed:(NSNotification *)notification
{
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"OK", "text label for ok")];
    cancelItem.action = ^{
        [_mediaPlayer stop];
        [[self navigationController] popViewControllerAnimated:YES];
    };
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Sorry", "text label for sorry") 
                                                        message:NSLocalizedString(@"EpisodePlaybackFailed", "text label for episode playback failed") 
                                               cancelButtonItem:cancelItem 
                                               otherButtonItems:nil];
    [alertView show];
}

/**
 * Invokced when the media playback state has changed. Syncs the play/pause button to match the current media player state.
 */
- (void)playbackStateChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    if ([[userInfo valueForKey:@"isPlaying"] boolValue])
    {
        [self hideBufferingHUD];
    }
    
    [self updatePlayButtonImage];
}

#pragma mark - UIApplication Notification Observer Methods 

/**
 * When the application enters the background stop the playback progress update timer because there is no need to be updating the UI while in the background.
 */
- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self stopPlaybackProgressUpdateTimer];
}

/**
 * When the application enters the foreground start updating the UI by starting the playback progress update timer.
 */
- (void)applicationDidEnterForeground:(NSNotification *)notification
{
    [self startPlaybackProgressUpdateTimer];
}

@end
