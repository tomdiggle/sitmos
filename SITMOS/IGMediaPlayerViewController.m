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

#import "IGMediaPlayerViewController.h"

#import "IGMediaPlayer.h"
#import "IGMediaPlayerAsset.h"
#import "IGEpisode.h"
#import "IGVideoPlayerViewController.h"
#import "CoreData+MagicalRecord.h"

@interface IGMediaPlayerViewController ()

@property (nonatomic, strong) IGMediaPlayerAsset *mediaPlayerAsset;

@end

@implementation IGMediaPlayerViewController

- (id)initWithMediaPlayerAsset:(IGMediaPlayerAsset *)asset
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _mediaPlayerAsset = asset;
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([_mediaPlayerAsset isAudio])
    {
        [self showAudioPlayer];
    }
    else
    {
        [self showVideoPlayer];
    }
}

#pragma mark - Audio Playing Methods

- (void)showAudioPlayer
{
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard"
                                                         bundle:[NSBundle mainBundle]];
    UIViewController *audioPlayer = [storyboard instantiateViewControllerWithIdentifier:@"IGAudioPlayerViewController"];
    [audioPlayer setTitle:[_mediaPlayerAsset title]];
    [[self navigationController] pushViewController:audioPlayer
                                           animated:NO];
    
    [self playAudio];
}

- (void)playAudio
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    if ([[_mediaPlayerAsset contentURL] isEqual:[[mediaPlayer asset] contentURL]]) return;
    
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[_mediaPlayerAsset title]];
    
    [mediaPlayer setStartFromTime:[[episode progress] floatValue]];
    [mediaPlayer startWithAsset:_mediaPlayerAsset];
    
    [mediaPlayer setPausedBlock:^(Float64 currentTime) {
        [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
            IGMediaPlayerAsset *localAsset = _mediaPlayerAsset;
            IGEpisode *localEpisode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                               withValue:[localAsset title]
                                                               inContext:localContext];
            [localEpisode setProgress:@(currentTime)];
        }];
    }];
    
    [mediaPlayer setStoppedBlock:^(Float64 currentTime, BOOL playbackEnded) {
        [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
            IGMediaPlayerAsset *localAsset = _mediaPlayerAsset;
            IGEpisode *localEpisode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                               withValue:[localAsset title]
                                                               inContext:localContext];
            
            NSNumber *progress = @(currentTime);
            if (playbackEnded)
            {
                progress = @(0);
                [localEpisode markAsPlayed:playbackEnded];
            }
            [localEpisode setProgress:progress];
        }];
    }];
}

#pragma mark - Video Playing Methods

- (void)showVideoPlayer
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    [mediaPlayer stop];
    
    [[self navigationItem] setHidesBackButton:YES];
    
    IGVideoPlayerViewController *videoPlayer = [[IGVideoPlayerViewController alloc] initWithContentURL:[_mediaPlayerAsset contentURL]];
    [[self navigationController] pushViewController:videoPlayer
                                           animated:NO];
}

@end
