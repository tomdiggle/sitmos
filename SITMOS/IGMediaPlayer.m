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
NSString * const IGMediaPlayerPlaybackLoading = @"IGMediaPlayerPlaybackLoading";
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

@property (strong, nonatomic) AVPlayer *player;
@property (strong, nonatomic) AVPlayerItem *playerItem;
@property (readwrite, nonatomic) Float64 currentTime;
@property (readwrite, nonatomic) Float64 duration;
@property (readwrite, nonatomic) IGMediaPlayerPlaybackState playbackState;
@property (nonatomic, strong, readwrite) IGMediaPlayerAsset *asset;

- (void)handleInterruptionChangeToState:(AudioQueuePropertyID)inInterruptionState;
- (void)handleAudioRouteChange:(const void *)inPropertyValue;

@end

void MyAudioSessionInterruptionListener(void *inClientData, UInt32 inInterruptionState);
void AudioRouteChangeListenerCallback(void *inClientData, AudioSessionPropertyID inID, UInt32 inDataSize, const void *inData);

/**
 * Invoked if the audio session is interrupted (like when the phone rings).
 */
void MyAudioSessionInterruptionListener(void *inClientData, UInt32 inInterruptionState)
{
    [__sharedInstance handleInterruptionChangeToState:inInterruptionState];
}

/**
 * Invoked if the audio route has changed. Used to detect when headphones are unplugged.
 */
void AudioRouteChangeListenerCallback(void *inClientData, AudioSessionPropertyID inID, UInt32 inDataSize, const void *inData)
{
    if (inID != kAudioSessionProperty_AudioRouteChange) return;
    
    [__sharedInstance handleAudioRouteChange:inData];
}

@implementation IGMediaPlayer

#pragma mark - Getting the Media Player Instance

+ (IGMediaPlayer *)sharedInstance
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
    if (!(self = [super init]))
    {
        return nil;
    }
    
    // Set the audio session category so that we continue to play if the iPhone/iPod auto-locks
    AudioSessionInitialize(NULL, NULL, MyAudioSessionInterruptionListener, (__bridge void *)self);
    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
    AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange, AudioRouteChangeListenerCallback, (__bridge void *)self);
    
    _player = nil;
    _startFromTime = 0.f;
    _duration = 0.f;
    _currentTime = 0.f;
    _playbackRate = 1.f;
    
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
    _currentTime = 0.f;
    _duration = 0.f;
}

#pragma mark - KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == IGMediaPlayerStatusObservationContext)
    {
        // AVPlayerItem "status" property value observer.
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
        // Replacement of player currentItem has occurred.
        AVPlayerItem *newPlayerItem = [change objectForKey:NSKeyValueChangeNewKey];
        
        /* Is the new player item null? */
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
    
    if ([_asset.contentURL isEqual:asset.contentURL])
    {
        return;
    }
    
    _asset = asset;

    // Calling pause, pauses any existing audio playing. Useful when switching from a downloaded episode to streaming one.
    [self pause];

    [self postNotification:IGMediaPlayerPlaybackLoading];

    AVURLAsset *urlAsset = [AVURLAsset assetWithURL:asset.contentURL];

    NSArray *requestedKeys = @[kTracksKey, kPlayableKey];

    // Tells the asset to load the values of any of the specified keys that are not already loaded.
    [urlAsset loadValuesAsynchronouslyForKeys:requestedKeys completionHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            // IMPORTANT: Must dispatch to main queue in order to operate on the AVPlayer and AVPlayerItem.
            [self prepareToPlayAsset:urlAsset
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
    // Make sure that the value of each key has loaded successfully.
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
    
    // Use the AVAsset playable property to detect whether the asset can be played.
    if (!asset.playable) 
    {
        [self playbackFailed];
        return;
    }
    
    // Stop observing our prior AVPlayerItem, if we have one.
    if (_playerItem)
    {
        // Remove existing player item key value observers and notifications.
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
	
    // Create a new instance of AVPlayerItem from the now successfully loaded AVAsset.
    _playerItem = [AVPlayerItem playerItemWithAsset:asset];
    
    // Observe the player item "status" key to determine when it is ready to play.
    [_playerItem addObserver:self 
                  forKeyPath:kStatusKey 
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerStatusObservationContext];
    
    // Observe the player item "duration" key to determine any duration changes.
    [_playerItem addObserver:self 
                  forKeyPath:kDurationKey 
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerDurationObservationContext];
    
    // Observe the player item "playbackBufferEmpty" key to determine if playback has consumed all buffered media and that playback will stall or end.
    [_playerItem addObserver:self
                  forKeyPath:kPlaybackBufferEmptyKey
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerPlaybackBufferEmptyObservationContext];
    
    // Observe the player item "playbackLikelyToKeepUp" key to detemine if the item will likely play through without stalling.
    [_playerItem addObserver:self
                  forKeyPath:kPlaybackLikelyToKeepUpKey
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerPlaybackLikelyToKeepUpObservationContext];
	
    // When the player item has played to its end time we'll reset the progress back to 0, remove the now playing info,
    // set the episode to nil and post a playback ended notification.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:_playerItem];
	
    // Create new player, if we don't already have one.
    if (!_player)
    {
        // Get a new AVPlayer initialized to play the specified player item.
        [self setPlayer:[AVPlayer playerWithPlayerItem:_playerItem]];
        
        [_player addObserver:self 
                  forKeyPath:kCurrentItemKey 
                     options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew
                     context:IGMediaPlayerCurrentItemObservationContext];
    }
    
    // Make our new AVPlayerItem the AVPlayer's current item.
    if (_player.currentItem != _playerItem)
    {
        [_player replaceCurrentItemWithPlayerItem:_playerItem];
    }
    
    // Set the audio session active
    AudioSessionSetActive(true);
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
    return CMTimeGetSeconds([_player currentTime]);
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
    MPMediaItemArtwork *propertyArtwork = [[MPMediaItemArtwork alloc] initWithImage:[UIImage imageNamed:@"audio-player-bg"]];
    NSDictionary *nowPlayingInfo = @{MPMediaItemPropertyTitle : [_asset title], MPMediaItemPropertyAlbumTitle : @"Stuck in the Middle of Somewhere", MPMediaItemPropertyArtist : @"Joel Gardiner and Derek Sweet", MPMediaItemPropertyArtwork : propertyArtwork};
    
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

#pragma mark - Audio Service Callback Method

- (void)handleInterruptionChangeToState:(AudioQueuePropertyID)inInterruptionState
{
	if (inInterruptionState == kAudioSessionBeginInterruption)
	{
		if ([self isPlaying]) 
        {
			[self pause];
            [self setPlaybackState:IGMediaPlayerPlaybackStatePausedByInterruption];
		} 
	}
	else if (inInterruptionState == kAudioSessionEndInterruption) 
	{
        UInt32 shouldResume = 0;
        UInt32 size = sizeof(shouldResume);
        
        if (_playbackState == IGMediaPlayerPlaybackStatePausedByInterruption)
        {
            if (!AudioSessionGetProperty(kAudioSessionProperty_InterruptionType, &size, &shouldResume) && shouldResume == kAudioSessionInterruptionType_ShouldResume && [self isPaused])
            {
                AudioSessionSetActive(TRUE);
                [self play];
            }
        }
	}
}

- (void)handleAudioRouteChange:(const void *)inPropertyValue
{
    CFDictionaryRef routeChangeDictionary = inPropertyValue;
    CFNumberRef routeChangeReasonRef = CFDictionaryGetValue(routeChangeDictionary, CFSTR(kAudioSession_AudioRouteChangeKey_Reason));
    SInt32 routeChangeReason;
    CFNumberGetValue(routeChangeReasonRef, kCFNumberSInt32Type, &routeChangeReason);
    
    if (routeChangeReason == kAudioSessionRouteChangeReason_OldDeviceUnavailable)
    {
        [self pause];
    }
}

@end
