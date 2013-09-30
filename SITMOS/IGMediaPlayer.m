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

#import "IGMediaPlayer.h"

#import "IGMediaPlayerAsset.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>

static IGMediaPlayer *__sharedInstance = nil;

/* Media Player Notifications */
NSString * const IGMediaPlayerPlaybackStatusChangedNotification = @"IGMediaPlayerPlaybackStatusChangedNotification";
NSString * const IGMediaPlayerPlaybackFailedNotification = @"IGMediaPlayerPlaybackFailedNotification";
NSString * const IGMediaPlayerPlaybackEndedNotification = @"IGMediaPlayerPlaybackEndedNotification";
NSString * const IGMediaPlayerPlaybackBufferEmptyNotification = @"IGMediaPlayerPlaybackBufferEmptyNotification";
NSString * const IGMediaPlayerPlaybackLikelyToKeepUpNotification = @"IGMediaPlayerPlaybackLikelyToKeepUpNotification";

/* Asset Keys */
NSString * const kTracksKey = @"tracks";
NSString * const kPlayableKey = @"playable";

/* PlayerItem keys */
NSString * const kStatusKey = @"status";
NSString * const kDurationKey = @"duration";
NSString * const kPlaybackLikelyToKeepUpKey = @"playbackLikelyToKeepUp";
NSString * const kPlaybackBufferEmptyKey =  @"playbackBufferEmpty";

/* AVPlayer keys */
NSString * const kCurrentItemKey = @"currentItem";

static void * IGMediaPlayerCurrentItemObservationContext = &IGMediaPlayerCurrentItemObservationContext;
static void * IGMediaPlayerStatusObservationContext = &IGMediaPlayerStatusObservationContext;
static void * IGMediaPlayerDurationObservationContext = &IGMediaPlayerDurationObservationContext;
static void * IGMediaPlayerPlaybackBufferEmptyObservationContext = &IGMediaPlayerPlaybackBufferEmptyObservationContext;
static void * IGMediaPlayerPlaybackLikelyToKeepUpObservationContext = &IGMediaPlayerPlaybackLikelyToKeepUpObservationContext;

@interface IGMediaPlayer ()

@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVURLAsset *urlAsset;
@property (nonatomic, readwrite) Float64 currentTime;
@property (nonatomic, readwrite) Float64 duration;
@property (nonatomic, readwrite) IGMediaPlayerPlaybackState playbackState;

@end

@implementation IGMediaPlayer

#pragma mark - Getting the Media Player Instance

+ (instancetype)sharedInstance
{
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        __sharedInstance = [[self alloc] init];
    });
    
    return __sharedInstance;
}

#pragma mark - Initializers

- (id)init
{
    if (!(self = [super init])) return nil;
    
    _startFromTime = 0.f;
    _duration = 0.f;
    _currentTime = 0.f;
    _playbackRate = 1.f;
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleInterruption:)
                                                 name:AVAudioSessionInterruptionNotification
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleAudioRouteChange:)
                                                 name:AVAudioSessionRouteChangeNotification
                                               object:nil];
    
    return self;
}

#pragma mark - Clean Up

/**
 * Invoked when playback is stopped or has reached the end.
 */
- (void)cleanUp
{
    _player = nil;
    _asset = nil;
    _urlAsset = nil;
    _pausedBlock = nil;
    _stoppedBlock = nil;
    _currentTime = 0.f;
    _duration = 0.f;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == IGMediaPlayerStatusObservationContext)
    {
        AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        switch (status)
        {
            case AVPlayerStatusReadyToPlay:
                [self addNowPlayingInfo];
                if (_startFromTime > 0)
                {
                    [self seekToTime:_startFromTime];
                    _startFromTime = 0.f;
                }
                [self play];
                
                break;
            case AVPlayerStatusFailed:
                [self playbackFailed];
                
                break;
                
            default:
                break;
        }
    }
    else if (context == IGMediaPlayerDurationObservationContext)
    {
        [self setDuration:CMTimeGetSeconds([[_playerItem asset] duration])];
    }
    else if (context == IGMediaPlayerCurrentItemObservationContext)
    {
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        if (newPlayerItem == (id)[NSNull null])
        {
            return;
        }
    }
    else if (context == IGMediaPlayerPlaybackBufferEmptyObservationContext)
    {
        [self postNotification:IGMediaPlayerPlaybackBufferEmptyNotification];
    }
    else if (context == IGMediaPlayerPlaybackLikelyToKeepUpObservationContext)
    {
        [self postNotification:IGMediaPlayerPlaybackLikelyToKeepUpNotification];
    }
    else
    {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark - Managing Playback

- (void)startWithAsset:(IGMediaPlayerAsset *)asset
{
    NSParameterAssert(asset != nil);
    
    if ([_asset.contentURL isEqual:asset.contentURL] && ![asset shouldRestoreState])
    {
        return;
    }
    
    // Stops any existing audio playing. Useful when switching from a downloaded episode to streaming one because streaming an episode can sometimes take a while to begin depending on the users connection.
    [self stop];
    
    _asset = asset;

    [self setPlaybackState:IGMediaPlayerPlaybackStateBuffering];

    _urlAsset = [AVURLAsset assetWithURL:asset.contentURL];

    NSArray *requestedKeys = @[kTracksKey, kPlayableKey];
    
    [_urlAsset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self prepareToPlayAsset:_urlAsset
                            withKeys:requestedKeys];
        });
    }];
}

/**
 * Invoked at the completion of the loading of the values for all keys on the asset that we require.
 * Checks whether loading was successful and whether the asset is playable.
 * If so, sets up an AVPlayerItem and an AVPlayer to play the asset.
 */
- (void)prepareToPlayAsset:(AVURLAsset *)asset withKeys:(NSArray *)requestedKeys
{
	for (NSString *thisKey in requestedKeys)
	{
		NSError *error = nil;
		AVKeyValueStatus keyStatus = [asset statusOfValueForKey:thisKey 
                                                          error:&error];
		if (keyStatus == AVKeyValueStatusFailed)
		{
            [self playbackFailed];
			return;
		}
	}
    
    if (!asset.playable) 
    {
        [self playbackFailed];
        return;
    }
    
    if (_playerItem)
    {
        [_playerItem removeObserver:self 
                         forKeyPath:kStatusKey];
        
        [_playerItem removeObserver:self
                         forKeyPath:kDurationKey];
        
        [_playerItem removeObserver:self
                         forKeyPath:kPlaybackBufferEmptyKey];
        
        [_playerItem removeObserver:self
                         forKeyPath:kPlaybackLikelyToKeepUpKey];
		
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AVPlayerItemDidPlayToEndTimeNotification
                                                      object:_playerItem];
    }
	
    _playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    [_playerItem addObserver:self 
                  forKeyPath:kStatusKey 
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerStatusObservationContext];
    
    [_playerItem addObserver:self 
                  forKeyPath:kDurationKey 
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerDurationObservationContext];
    
    [_playerItem addObserver:self
                  forKeyPath:kPlaybackBufferEmptyKey
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerPlaybackBufferEmptyObservationContext];
    
    [_playerItem addObserver:self
                  forKeyPath:kPlaybackLikelyToKeepUpKey
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerPlaybackLikelyToKeepUpObservationContext];
	
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:_playerItem];
	
    if (!_player)
    {
        [self setPlayer:[AVPlayer playerWithPlayerItem:_playerItem]];
        
        [_player addObserver:self 
                  forKeyPath:kCurrentItemKey 
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerCurrentItemObservationContext];
    }
    
    if (_player.currentItem != _playerItem)
    {
        [_player replaceCurrentItemWithPlayerItem:_playerItem];
    }
    
    [[AVAudioSession sharedInstance] setActive:YES error:nil];
}

- (void)play
{
    [_player setRate:_playbackRate];
    [self setPlaybackState:IGMediaPlayerPlaybackStatePlaying];
    [self postNotification:IGMediaPlayerPlaybackStatusChangedNotification];
}

- (void)pause
{
    [_player pause];
    if (_pausedBlock)
    {
        _pausedBlock([self currentTime]);
    }
    [self setPlaybackState:IGMediaPlayerPlaybackStatePaused];
    [self postNotification:IGMediaPlayerPlaybackStatusChangedNotification];
}

- (void)stop
{
    [_player pause];
    if (_stoppedBlock)
    {
        _stoppedBlock([self currentTime], NO);
    }
    [self setPlaybackState:IGMediaPlayerPlaybackStateStopped];
    [self postNotification:IGMediaPlayerPlaybackStatusChangedNotification];
    [self cleanUp];
}

- (void)beginSeekingForward
{
    [self setPlaybackState:IGMediaPlayerPlaybackStateSeekingForward];
    [_player setRate:2.0f];
}

- (void)beginSeekingBackward
{
    [self setPlaybackState:IGMediaPlayerPlaybackStateSeekingBackward];
    [_player setRate:-2.0f];
}

- (void)endSeeking
{
    [self play];
}

- (void)seekToBeginning
{
    [_player seekToTime:kCMTimeZero];
}

- (BOOL)isPlaying
{
    return [_player rate] > 0.01;
}

- (BOOL)isPaused
{
    return [_player rate] < 0.01;
}

- (Float64)availableDuration
{
    NSArray *loadedTimeRanges = [[_player currentItem] loadedTimeRanges];
    
    if ([loadedTimeRanges count] == 0)
    {
        return 0.0f;
    }
    
    CMTimeRange timeRange = [[loadedTimeRanges objectAtIndex:0] CMTimeRangeValue];
    Float64 startSeconds = CMTimeGetSeconds(timeRange.start);
    Float64 durationSeconds = CMTimeGetSeconds(timeRange.duration);
    
    return startSeconds + durationSeconds;
}

- (void)setPlaybackRate:(float)playbackRate
{
    if (_playbackRate != playbackRate)
    {
        _playbackRate = playbackRate;
        
        if (![self isPaused])
        {
            // If the player rate is changed while playback is paused
            // playback will resume which is not what the user will expect.
            [_player setRate:playbackRate];
        }
    }
}

/**
 * Invoked when the playback has ended. Sets the episode progress back to 0, removes the now playing info and posts the notification IGMediaPlayerPlaybackEndedNotification.
 */
- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    if (_stoppedBlock)
    {
        _stoppedBlock([self currentTime], YES);
    }
    [self removeNowPlayingInfo];
    [self postNotification:IGMediaPlayerPlaybackEndedNotification];
    [self cleanUp];
}

- (void)playbackFailed
{
    [self postNotification:IGMediaPlayerPlaybackFailedNotification];
    [self cleanUp];
}

#pragma mark - Managing Time

- (Float64)currentTime
{
    return CMTIME_IS_VALID([self.player currentTime]) ? CMTimeGetSeconds([_player currentTime]) : 0.f;
}

- (void)seekToTime:(Float64)time
{
    [_player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
}

#pragma mark - Notifications

- (void)postNotification:(NSString *)notificationName
{
    NSNotification *notification = [NSNotification notificationWithName:notificationName
                                                                 object:self
                                                               userInfo:nil];
    // Notifications are posted on the main thread.
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    });
}

#pragma mark - MPNowPlayingInfoCenter

/**
 * Invoked when playback is started. Gets the title, artist and album title from the players current item and asset and sets the now playing info.
 */
- (void)addNowPlayingInfo
{
    NSNumber *duration = !isnan(self.duration) ? @(self.duration) : @(0);
    MPMediaItemArtwork *propertyArtwork = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"audio-player-bg"]];
    NSDictionary *nowPlayingInfo = @{ MPMediaItemPropertyTitle : [self.asset title],
                                      MPMediaItemPropertyAlbumTitle : @"Stuck in the Middle of Somewhere",
                                      MPMediaItemPropertyArtist : @"Joel Gardiner and Derek Sweet",
                                      MPMediaItemPropertyArtwork : propertyArtwork,
                                      MPMediaItemPropertyPlaybackDuration : duration,
                                      MPNowPlayingInfoPropertyPlaybackRate : @(self.playbackRate),
                                      MPNowPlayingInfoPropertyElapsedPlaybackTime : @(self.startFromTime) };
    MPNowPlayingInfoCenter *playingInfoCenter = [MPNowPlayingInfoCenter defaultCenter];
    [playingInfoCenter setNowPlayingInfo:nowPlayingInfo];
}

/**
 * Invoked when playback is stopped. Removes the now playing info.
 */
- (void)removeNowPlayingInfo
{
    MPNowPlayingInfoCenter *playingInfoCenter = [MPNowPlayingInfoCenter defaultCenter];
    [playingInfoCenter setNowPlayingInfo:nil];
}

#pragma mark - Handle Interruptions

- (void)handleInterruption:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSUInteger interruptionType = [[userInfo objectForKey:AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (interruptionType == AVAudioSessionInterruptionTypeBegan)
    {
        if ([self isPlaying])
        {
			[self pause];
            [self setPlaybackState:IGMediaPlayerPlaybackStatePausedByInterruption];
		}
    }
    else if (interruptionType == AVAudioSessionInterruptionTypeEnded)
    {
        NSUInteger interruptionOption = [[userInfo objectForKey:AVAudioSessionInterruptionOptionKey] unsignedIntegerValue];
        if (interruptionOption == AVAudioSessionInterruptionOptionShouldResume)
        {
            [[AVAudioSession sharedInstance] setActive:YES error:nil];
            [self play];
        }
    }
}

#pragma mark - Handle Audio Route Change

- (void)handleAudioRouteChange:(NSNotification *)notification
{
    NSDictionary *userInfo = [notification userInfo];
    NSUInteger routeChangeReason = [[userInfo objectForKey:AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (routeChangeReason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable)
    {
        [self pause];
    }
}

@end
