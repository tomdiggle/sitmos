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

#import "IGEpisode.h"
#import "IGMediaPlayer.h"
#import "IGMediaAsset.h"
#import "IGDefines.h"
#import "TDNotificationPanel.h"
#import "TestFlight.h"

NSString * const kPlaybackStateKey = @"playbackState";

static void * IGMediaPlayerPlaybackStateContext = &IGMediaPlayerPlaybackStateContext;

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
    [self.mediaPlayer removeObserver:self forKeyPath:kPlaybackStateKey context:IGMediaPlayerPlaybackStateContext];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Initializers

- (id)initWithCoder:(NSCoder *)coder
{
    if (!(self = [super initWithCoder:coder]))
    {
        return nil;
    }
    
    self.mediaPlayer = [IGMediaPlayer sharedInstance];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterBackground:)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidEnterForeground:)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];
    
    return self;
}

#pragma mark - State Preservation and Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    
    // Save the current playing episodes URIRepresentation, which we can use to look up the episode on restore and call loadAudioPlayerWithEpisode: method.
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[[self.mediaPlayer asset] title]];
    [coder encodeObject:[[episode objectID] URIRepresentation] forKey:@"episodeURIRepresentation"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    
    NSURL *episodeURI = [coder decodeObjectForKey:@"episodeURIRepresentation"];
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    NSManagedObjectID *episodeObjectID = [[context persistentStoreCoordinator] managedObjectIDForURIRepresentation:episodeURI];
    if (episodeObjectID)
    {
        IGEpisode *episode = (IGEpisode *)[context objectWithID:episodeObjectID];
        [self loadAudioPlayerWithEpisode:episode];
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self.mediaPlayer addObserver:self forKeyPath:kPlaybackStateKey options:NSKeyValueObservingOptionInitial|NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:IGMediaPlayerPlaybackStateContext];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"media-player-hide-button"]
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(hideAudioPlayer:)];
    
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

- (void)showPlayButtonImage
{
    [self.playButton setImage:[UIImage imageNamed:@"play-button"] forState:UIControlStateNormal];
    [self.playButton setAccessibilityLabel:NSLocalizedString(@"Play", nil)];
    [self.playButton setAccessibilityHint:NSLocalizedString(@"PlaysEpisode", nil)];
}

- (void)showPauseButtonImage
{
    [self.playButton setImage:[UIImage imageNamed:@"pause-button"] forState:UIControlStateNormal];
    [self.playButton setAccessibilityLabel:NSLocalizedString(@"Pause", nil)];
    [self.playButton setAccessibilityHint:NSLocalizedString(@"PausesEpisode", nil)];
}

- (void)updatePlaybackProgress
{
    if (isnan([self.mediaPlayer duration])) return;
    
    [self.currentTime setText:[self currentTimeString]];
    [self.duration setText:[self durationString]];
    [self.progressSlider setMaximumValue:[self.mediaPlayer duration]];
    [self.progressSlider setValue:[self.mediaPlayer currentTime]];
}

- (void)showBufferingIndicator
{
    [self.bufferingIndicator startAnimating];
    [self.currentTime setHidden:YES];
}

- (void)hideBufferingIndicator
{
    if (![self.bufferingIndicator isAnimating]) return;
    
    [self.bufferingIndicator stopAnimating];
    [self.currentTime setHidden:NO];
}

#pragma mark - Hide Audio Player

- (void)hideAudioPlayer:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Playback

- (void)loadAudioPlayerWithEpisode:(IGEpisode *)episode
{
    self.title = episode.title;
    
    NSURL *contentURL = ([episode isDownloaded]) ? [episode fileURL] : [NSURL URLWithString:[episode downloadURL]];
    IGMediaAsset *asset = [[IGMediaAsset alloc] initWithTitle:[episode title]
                                                   contentURL:contentURL
                                                      isAudio:[episode isAudio]];
    
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    if ([[mediaPlayer.asset title] isEqualToString:asset.title] && mediaPlayer.playbackState == IGMediaPlayerPlaybackStatePlaying)
    {
        // No need to reload the media that is already playing
        return;
    }
    
    // Stop any media playing before loading new media so the current media's position gets saved
    [mediaPlayer stop];
    
    [mediaPlayer setStartFromTime:[[episode progress] floatValue]];
    [mediaPlayer startWithAsset:asset];
    
    [mediaPlayer setPausedBlock:^(Float64 currentTime) {
        NSManagedObjectContext *localContext = [NSManagedObjectContext MR_defaultContext];
        IGEpisode *localEpisode = [episode MR_inContext:localContext];
        [localEpisode setProgress:@(currentTime)];
        [localContext MR_saveToPersistentStoreAndWait];
    }];
    
    [mediaPlayer setStoppedBlock:^(Float64 currentTime, BOOL playbackEnded) {
        NSManagedObjectContext *localContext = [NSManagedObjectContext MR_defaultContext];
        IGEpisode *localEpisode = [episode MR_inContext:localContext];
        NSNumber *progress = @(currentTime);
        if (playbackEnded)
        {
            progress = @(0);
            [localEpisode markAsPlayed:playbackEnded];
        }
        [localEpisode setProgress:progress];
        [localContext MR_saveToPersistentStoreAndWait];
    }];
    
    NSString *from = ([episode isDownloaded]) ? @"download" : @"stream";
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"Playing %@ from %@", [episode title], from]];
}

- (IBAction)playButtonTapped:(id)sender
{
    if ([self.mediaPlayer playbackState] == IGMediaPlayerPlaybackStatePaused)
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
    [self.mediaPlayer play];
}

- (void)pause
{
    [self stopPlaybackProgressUpdateTimer];
    [self.mediaPlayer pause];
}

- (IBAction)seekForward:(id)sender
{
    if ([sender isKindOfClass:[UILongPressGestureRecognizer class]])
    {
        if ([sender state] == UIGestureRecognizerStateBegan)
        {
            [self.mediaPlayer beginSeekingForward];
        }
        else if ([sender state] == UIGestureRecognizerStateEnded)
        {
            if ([self.mediaPlayer playbackState] == IGMediaPlayerPlaybackStateSeekingForward)
            {
                [self.mediaPlayer endSeeking];
            }
        }
    }
    else
    {
        NSUInteger skipForwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGPlayerSkipForwardPeriodKey];
        [self.mediaPlayer seekToTime:[self.mediaPlayer currentTime] + (float)skipForwardTime];
    }
}

- (IBAction)seekBackward:(id)sender
{
    if ([sender isKindOfClass:[UILongPressGestureRecognizer class]])
    {
        if ([sender state] == UIGestureRecognizerStateBegan)
        {
            [self.mediaPlayer beginSeekingBackward];
        }
        else if ([sender state] == UIGestureRecognizerStateEnded)
        {
            if ([self.mediaPlayer playbackState] == IGMediaPlayerPlaybackStateSeekingBackward)
            {
                [self.mediaPlayer endSeeking];
            }
        }
    }
    else
    {
        NSUInteger skipBackwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGPlayerSkipBackPeriodKey];
        [self.mediaPlayer seekToTime:[self.mediaPlayer currentTime] - (float)skipBackwardTime];
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
    [self.mediaPlayer seekToTime:newSeekTime];
    
    [self.currentTime setText:[self currentTimeString]];
    [self.duration setText:[self durationString]];
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
    Float64 currentTime = [self.mediaPlayer currentTime];
    
    NSInteger secondsPlayed = (NSInteger)currentTime % 60;
    NSInteger minutesPlayed = (NSInteger)currentTime / 60 % 60;
    NSInteger hoursPlayed = ((NSInteger)currentTime / 60) / 60;
    
    return [NSString stringWithFormat:@"%2d:%02d:%02d", hoursPlayed, minutesPlayed, secondsPlayed];
}

- (NSString *)durationString
{
    Float64 currentTime = [self.mediaPlayer currentTime];
    Float64 duration = [self.mediaPlayer duration];
    
    NSInteger secondsLeft = ((NSInteger)duration - (NSInteger)currentTime) % 60;
    NSInteger minutesLeft = ((NSInteger)duration - (NSInteger)currentTime) / 60 % 60;
    NSInteger hoursLeft = (((NSInteger)duration - (NSInteger)currentTime) / 60) / 60;
    
    return [NSString stringWithFormat:@"-%1d:%02d:%02d", hoursLeft, minutesLeft, secondsLeft];
}

#pragma mark - Playback Progress

- (void)startPlaybackProgressUpdateTimer
{
    if ([self.playbackProgressUpdateTimer isValid]) return;
    
    self.playbackProgressUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:0.2
                                                                        target:self
                                                                      selector:@selector(updatePlaybackProgress)
                                                                      userInfo:nil
                                                                       repeats:YES];
}

- (void)stopPlaybackProgressUpdateTimer
{
    if (![self.playbackProgressUpdateTimer isValid]) return;
    
    [self.playbackProgressUpdateTimer invalidate];
}

#pragma mark - Media Player Notification Observer Methods

- (void)playbackEnded
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)playbackFailed
{
    [TDNotificationPanel showNotificationInView:self.view.window
                                          title:NSLocalizedString(@"EpisodePlaybackFailed", nil)
                                       subtitle:nil
                                           type:TDNotificationTypeError
                                           mode:TDNotificationModeText
                                    dismissible:YES
                                 hideAfterDelay:4];
    
    [self dismissViewControllerAnimated:YES completion:nil];
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

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == IGMediaPlayerPlaybackStateContext && [keyPath isEqualToString:kPlaybackStateKey])
    {
        switch ([(IGMediaPlayer *)object playbackState]) {
            case IGMediaPlayerPlaybackStateLoading:
            case IGMediaPlayerPlaybackStateBuffering:
                [self showBufferingIndicator];
                break;
            case IGMediaPlayerPlaybackStatePlaying:
                [self hideBufferingIndicator];
                [self showPauseButtonImage];
                break;
            case IGMediaPlayerPlaybackStatePausedByInterruption:
            case IGMediaPlayerPlaybackStatePaused:
                [self showPlayButtonImage];
                break;
            case IGMediaPlayerPlaybackStateDidReachEnd:
                [self playbackEnded];
                break;
            case IGMediaPlayerPlaybackStateFailed:
                [self playbackFailed];
                break;
            default:
                break;
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
