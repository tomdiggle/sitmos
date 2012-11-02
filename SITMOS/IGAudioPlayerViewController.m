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
#import "IGEpisodeDownloadOperation.h"
#import "IGEpisode.h"
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
@property (strong, nonatomic) IBOutlet UIButton *skippingBackButton;
@property (strong, nonatomic) IBOutlet UILabel *skippingBackLabel;
@property (strong, nonatomic) IBOutlet UIButton *shareButton;
@property (strong, nonatomic) IBOutlet UIImageView *backgroundImageView;
@property (strong, nonatomic) IBOutlet UIView *lowerPlayerControls;
@property (strong, nonatomic) IBOutlet UIButton *playButton;
@property (strong, nonatomic) IBOutlet UIButton *nextTrackButton;
@property (strong, nonatomic) IBOutlet UIButton *previousTrackButton;
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
    
    [self setTitle:[_episode title]];
    
    _mediaPlayer = [IGMediaPlayer sharedInstance];
    
    [self startPlayback];
    
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

#pragma mark - IBActions

- (IBAction)skippingBackButtonTapped:(id)sender
{
    CABasicAnimation *rotationAnimation;
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat:-M_PI * 2.0];
    rotationAnimation.duration = 0.4f;
    rotationAnimation.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    [_skippingBackButton.layer addAnimation:rotationAnimation
                                       forKey:@"rotationAnimation"];
    [_mediaPlayer seekToTime:[_mediaPlayer currentTime] - 30.0f];
    
    if ([_mediaPlayer isPaused])
    {
        [self updatePlaybackProgress];
    }
}

- (IBAction)playButtonTapped:(id)sender
{
    if ([[_playButton currentImage] isEqual:[UIImage imageNamed:@"play-button"]])
	{
        [_playButton setImage:[UIImage imageNamed:@"pause-button"] forState:UIControlStateNormal];
		[self play];
	}
	else
	{
        [_playButton setImage:[UIImage imageNamed:@"play-button"] forState:UIControlStateNormal];
		[self pause];
	}
}

/**
 * Invoked when the next track button is held down for more than 1 second.
 */
- (IBAction)seekForward:(id)sender
{
    int64_t delayInSeconds = 1.0;
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [_mediaPlayer beginSeekingForward];
    });
}

- (IBAction)nextTrackButtonTapped:(id)sender
{
    if ([_mediaPlayer playbackState] == IGMediaPlayerPlaybackStateSeekingForward)
    {
        [_mediaPlayer endSeeking];
    }
    else
    {
        IGEpisode *nextEpisode = [_episode nextEpisode];
        
        if (nextEpisode)
        {
            [self setEpisode:nextEpisode];
            [self setTitle:[nextEpisode title]];
            [self startPlayback];
        }
    }
}

- (IBAction)previousTrackButtonTapped:(id)sender
{
    IGEpisode *previousEpisode = [_episode previousEpisode];
    
    if (previousEpisode)
    {
        [self setEpisode:previousEpisode];
        [self setTitle:[previousEpisode title]];
        [self startPlayback];
    }
}

/**
 Invoked when user moves slider. The time played and time left labels 
 get updated while the slider is moving.
 */
- (IBAction)seekToTime:(UISlider *)slider
{
    Float64 newSeekTime = [slider value];
    [_mediaPlayer seekToTime:newSeekTime];
    
    [_currentTimeLabel setText:[self currentTimeString]];
    [_durationLabel setText:[self durationString]];
}

/**
 Invoked when the progress slider is touched down. Stops the playback progress update timer
 from updating the progress slider while the user is seeking.
 */
- (IBAction)seekToTimeStart:(UISlider *)slider
{
    [self stopPlaybackProgressUpdateTimer];
}

/**
 Invoked when the progress slider is touched up. Starts the playback progress update timer
 so the progress slider can be updated with the current playback progress and restarts playback.
 */
- (IBAction)seekToTimeStop:(UISlider *)slider
{
    [self startPlaybackProgressUpdateTimer];
    [self play];
}

- (IBAction)shareEpisodeButtonTapped:(id)sender
{
    NSString *shareText = [NSString stringWithFormat:@"%@ %@ %@ Stuck in the Middle of Somewhere http://sitmos.net/audio.php", NSLocalizedString(@"CheckOut", "text label for check out"), [_episode title], NSLocalizedString(@"Of", "text label for of")];
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
        [_playbackSpeedButton setImage:[UIImage imageNamed:@"playback-speed-1x"] forState:UIControlStateNormal];
        [_mediaPlayer setPlaybackRate:1.0f];
    }
    else if ([[sender imageForState:UIControlStateNormal] isEqual:[UIImage imageNamed:@"playback-speed-1-5x"]])
    {
        [_playbackSpeedButton setImage:[UIImage imageNamed:@"playback-speed-2x"] forState:UIControlStateNormal];
        [_mediaPlayer setPlaybackRate:2.0f];
    }
    else
    {
        [_playbackSpeedButton setImage:[UIImage imageNamed:@"playback-speed-1-5x"] forState:UIControlStateNormal];
        [_mediaPlayer setPlaybackRate:1.5f];
    }
}

#pragma mark - Playback Methods

/**
 Invoked when viewDidLoad is called. Starts playback of episode.
 */
- (void)startPlayback
{
    [self startPlaybackProgressUpdateTimer];
    
    dispatch_queue_t startPlaybackQueue = dispatch_queue_create("com.IdleGeniusSoftware.SITMOS.startPlaybackQueue", NULL);
	dispatch_async(startPlaybackQueue, ^{
        if (![[_mediaPlayer episode] isEqual:_episode])
        {
            [self showBufferingHUD];
            
            // Stop any media that is already playing so the position is saved
            [_mediaPlayer stop];
            [_mediaPlayer setEpisode:_episode];
            
            [_mediaPlayer start];
        }
        else
        {
            // This episode is already loaded into the media player so just
            // continue playing.
            [self play];
        }
	});
}

/**
 Begins playback of episode.
 */
- (void)play
{
    [self startPlaybackProgressUpdateTimer];
    
    [_mediaPlayer play];
    
    [_playButton setImage:[UIImage imageNamed:@"pause-button"] forState:UIControlStateNormal];
}

/**
 Pauses playback of episode.
 */
- (void)pause
{
    [self stopPlaybackProgressUpdateTimer];
    
    [_mediaPlayer pause];
    
    [_playButton setImage:[UIImage imageNamed:@"play-button"] forState:UIControlStateNormal];
}

#pragma mark - Timing

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
    
    return hoursLeft > 0 ? [NSString stringWithFormat:@"%2d:%02d:%02d", hoursLeft, minutesLeft, secondsLeft] : [NSString stringWithFormat:@"%2d:%02d", minutesLeft, secondsLeft];
}

#pragma mark - Buffering HUD

/**
 Shows the buffering hud on the main thread if it's not already being displayed.
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
        
        // Only show the buffering hud if episode is streaming
        if (![_episode isCompletelyDownloaded])
        {
            [_bufferingHUD show:YES];
        }
    });
}

/**
 Hides the buffering hud if it's being displayed.
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
 Invoked while audio is playing by the playback progress update timer.
 Updates the progress slider's progress value and the time played and time
 left labels.
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
 When playback has finsihed pop the view back to the episode lists view controller.
 */
- (void)playbackEnded:(NSNotification *)notification
{
    // Delete episode automatically once it has been played?
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults boolForKey:IGSettingEpisodesDelete])
    {
        [_episode deleteDownloadedEpisode];
    }
    
    [[self navigationController] popViewControllerAnimated:YES];
}

/**
 Invoked when playback fails. Displays an error message to user and will pop the view controller back to the 
 episodes list when OK is tapped.
 */
- (void)playbackFailed:(NSNotification *)notification
{
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"OK", "text label for OK")];
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
 Invokced when the media playback state has changed.
 Syncs the play/pause button to match the current media player state.
 */
- (void)playbackStateChanged:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    
    if (![[userInfo valueForKey:@"episodeTitle"] isEqual:[_episode title]])
    {
        [self setEpisode:[_mediaPlayer episode]];
        [self setTitle:[_episode title]];
        
        // This is here for when the audio is paused and next/previous episode
        // button is pressed. It re-starts the progress update timer.
        [self startPlaybackProgressUpdateTimer];
    }

    
    if ([[userInfo valueForKey:@"isPlaying"] boolValue])
    {
        [_playButton setImage:[UIImage imageNamed:@"pause-button"] forState:UIControlStateNormal];
        [self hideBufferingHUD];
    }
    else
    {
        [_playButton setImage:[UIImage imageNamed:@"play-button"] forState:UIControlStateNormal];
    }
}

#pragma mark - UIApplication Notification Observer Methods 

/**
 When the application enters the background stop the playback progress update timer
 because there is no need to be updating the UI while in the background.
 */
- (void)applicationDidEnterBackground:(NSNotification *)notification
{
    [self stopPlaybackProgressUpdateTimer];
}

/**
 When the application enters the foreground start updating the UI by starting
 the playback progress update timer.
 */
- (void)applicationDidEnterForeground:(NSNotification *)notification
{
    [self startPlaybackProgressUpdateTimer];
}

@end
