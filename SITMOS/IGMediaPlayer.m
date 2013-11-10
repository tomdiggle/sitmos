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

#import "IGMediaPlayer.h"

#import "IGMediaAsset.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <MediaPlayer/MediaPlayer.h>

/* Saved Asset */
static NSString * const IGMediaPlayerCurrentAssetKey = @"MediaPlayerCurrentAsset";

/* Media Player Notifications */
NSString * const IGMediaPlayerPlaybackStateLoadingNotification = @"com.idlegeniussoftware.media-player.playback.state.loading";
NSString * const IGMediaPlayerPlaybackStateBufferingNotification = @"com.idlegeniussoftware.media-player.playback.state.buffering";
NSString * const IGMediaPlayerPlaybackStatePlayingNotification = @"com.idlegeniussoftware.media-player.playback.state.playing";
NSString * const IGMediaPlayerPlaybackStatePausedNotification = @"com.idlegeniussoftware.media-player.playback.state.paused";
NSString * const IGMediaPlayerPlaybackStateStoppedNotification = @"com.idlegeniussoftware.media-player.playback.state.stopped";
NSString * const IGMediaPlayerPlaybackStateSeekingForwardNotification = @"com.idlegeniussoftware.media-player.playback.state.seeking-forward";
NSString * const IGMediaPlayerPlaybackStateSeekingBackwardNotification = @"com.idlegeniussoftware.media-player.playback.state.seeking-backward";
NSString * const IGMediaPlayerPlaybackStateDidReachEndNotification = @"com.idlegeniussoftware.media-player.playback.state.did-reach-end";
NSString * const IGMediaPlayerPlaybackStateFailedNotification = @"com.idlegeniussoftware.media-player.playback.state.failed";
NSString * const IGMediaPlayerPlaybackLikelyToKeepUpNotification = @"com.idlegeniussoftware.media-player.playback.likely-to-keep-up";

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
@property (nonatomic, strong, readwrite) IGMediaAsset *asset;

@end

@implementation IGMediaPlayer

#pragma mark - Getting the Media Player Instance

+ (instancetype)sharedInstance
{
    static IGMediaPlayer *__sharedInstance = nil;
    static dispatch_once_t once = 0;
    dispatch_once(&once, ^{
        __sharedInstance = [[self alloc] init];
    });
    
    return __sharedInstance;
}

#pragma mark - Memory Management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

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

#pragma mark - Initializers

- (id)init
{
    if (!(self = [super init])) return nil;
    
    _startFromTime = 0.f;
    _duration = 0.f;
    _currentTime = 0.f;
    _playbackRate = 1.f;
    
    NSData *assetData = [[NSUserDefaults standardUserDefaults] objectForKey:IGMediaPlayerCurrentAssetKey];
    if (assetData)
    {
        IGMediaAsset *asset = [NSKeyedUnarchiver unarchiveObjectWithData:assetData];
        self.asset = asset;
    }
    
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
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStateBufferingNotification object:self userInfo:nil]];
        });
    }
    else if (context == IGMediaPlayerPlaybackLikelyToKeepUpObservationContext)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackLikelyToKeepUpNotification object:self userInfo:nil]];
        });
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - Managing Playback

- (void)startWithAsset:(IGMediaAsset *)asset
{
    NSParameterAssert(asset != nil);
    
    self.asset = asset;
    
    [self setPlaybackState:IGMediaPlayerPlaybackStateLoading];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStateLoadingNotification object:self userInfo:nil]];
    });
    
    self.urlAsset = [AVURLAsset assetWithURL:asset.contentURL];
    
    NSArray *requestedKeys = @[kTracksKey, kPlayableKey];
    [self.urlAsset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            [self prepareToPlayAsset:self.urlAsset
                            withKeys:requestedKeys];
        });
    }];
    
    // Save the asset so it can be restored later if necessary. The saved asset will be removed if playback has failed or reached the end.
    NSData *assetData = [NSKeyedArchiver archivedDataWithRootObject:self.asset];
    [[NSUserDefaults standardUserDefaults] setObject:assetData forKey:IGMediaPlayerCurrentAssetKey];
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
    [self setPlaybackState:IGMediaPlayerPlaybackStatePlaying];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStatePlayingNotification object:self userInfo:nil]];
    });
    
    [self.player setRate:self.playbackRate];
    
    [self updateNowPlayingInfoPlaybackRate:@(self.playbackRate)];
}

- (void)pause
{
    [self setPlaybackState:IGMediaPlayerPlaybackStatePaused];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStatePausedNotification object:self userInfo:nil]];
    });
    
    [self.player pause];
    
    if (self.pausedBlock)
    {
        self.pausedBlock([self currentTime]);
    }
    
    [self updateNowPlayingInfoPlaybackRate:@(0.0)];
}

- (void)stop
{
    [self setPlaybackState:IGMediaPlayerPlaybackStateStopped];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStateStoppedNotification object:self userInfo:nil]];
    });
    
    [_player pause];
    if (_stoppedBlock)
    {
        _stoppedBlock([self currentTime], NO);
    }
    
    [self cleanUp];
}

- (void)beginSeekingForward
{
    [self setPlaybackState:IGMediaPlayerPlaybackStateSeekingForward];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStateSeekingForwardNotification object:self userInfo:nil]];
    });
    
    [self.player setRate:2.0f];
    
    [self updateNowPlayingInfoPlaybackRate:@(2.0f)];
}

- (void)beginSeekingBackward
{
    [self setPlaybackState:IGMediaPlayerPlaybackStateSeekingBackward];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStateSeekingBackwardNotification object:self userInfo:nil]];
    });
    
    [self.player setRate:-2.0f];
    
    [self updateNowPlayingInfoPlaybackRate:@(-2.0f)];
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

- (void)playerItemDidReachEnd:(NSNotification *)notification
{
    [self setPlaybackState:IGMediaPlayerPlaybackStateDidReachEnd];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStateDidReachEndNotification object:self userInfo:nil]];
    });
    
    if (_stoppedBlock)
    {
        _stoppedBlock([self currentTime], YES);
    }
    
    [self removeNowPlayingInfo];

    [self cleanUp];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:IGMediaPlayerCurrentAssetKey];
}

- (void)playbackFailed
{
    [self setPlaybackState:IGMediaPlayerPlaybackStateFailed];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:IGMediaPlayerPlaybackStateFailedNotification object:self userInfo:nil]];
    });
    
    [self cleanUp];
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:IGMediaPlayerCurrentAssetKey];
}

#pragma mark - Managing Time

- (Float64)currentTime
{
    return CMTIME_IS_VALID([self.player currentTime]) ? CMTimeGetSeconds([_player currentTime]) : 0.f;
}

- (void)seekToTime:(Float64)time
{
    [_player seekToTime:CMTimeMakeWithSeconds(time, NSEC_PER_SEC)];
    
    MPNowPlayingInfoCenter *playingInfoCenter = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionaryWithDictionary:playingInfoCenter.nowPlayingInfo];
    [nowPlayingInfo setObject:@(time) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [playingInfoCenter setNowPlayingInfo:nowPlayingInfo];
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

/**
 *
 */
- (void)updateNowPlayingInfoPlaybackRate:(NSNumber *)playbackRate
{
    MPNowPlayingInfoCenter *playingInfoCenter = [MPNowPlayingInfoCenter defaultCenter];
    NSMutableDictionary *nowPlayingInfo = [NSMutableDictionary dictionaryWithDictionary:playingInfoCenter.nowPlayingInfo];
    [nowPlayingInfo setObject:playbackRate forKey:MPNowPlayingInfoPropertyPlaybackRate];
    [nowPlayingInfo setObject:@(self.currentTime) forKey:MPNowPlayingInfoPropertyElapsedPlaybackTime];
    [playingInfoCenter setNowPlayingInfo:nowPlayingInfo];
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
