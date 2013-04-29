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
#import "IGDefines.h"
#import "IGHTTPClient.h"
#import "IGAudioPlayerViewController.h"
#import "CoreData+MagicalRecord.h"
#import "UIAlertView+Blocks.h"
#import "RIButtonItem.h"

@interface IGMediaPlayerViewController ()

@end

@implementation IGMediaPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self showAudioPlayer];
    
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    if (![httpClient allowCellularDataStreaming] && ![[_mediaPlayerAsset contentURL] isFileURL]) {
        [self showCellularDataStreamingAlert];
    } else {
        [self playAudio];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Segue Methods

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    IGAudioPlayerViewController *audioPlayerViewController = [segue destinationViewController];
    [audioPlayerViewController setTitle:[_mediaPlayerAsset title]];
}

#pragma mark - Audio Playing Methods

- (void)showAudioPlayer {
    [self performSegueWithIdentifier:@"showAudioPlayer"
                              sender:self];
}

- (void)playAudio {
    IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                  withValue:[_mediaPlayerAsset title]];
    
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
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
            if (playbackEnded) {
                progress = @(0);
                [localEpisode markAsPlayed:playbackEnded];
            }
            [localEpisode setProgress:progress];
        }];
    }];
}

#pragma mark - Cellular Data Streaming Alert

- (void)showCellularDataStreamingAlert {
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", "text label for cancel")];
    cancelItem.action = ^{
        [self dismissViewControllerAnimated:YES
                                 completion:nil];
    };
    RIButtonItem *streamItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Stream", @"text label for stream")];
    streamItem.action = ^{
        [self playAudio];
    };
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"StreamingWithCellularDataTitle", @"text label for streaming with cellular data title")
                                                        message:NSLocalizedString(@"StreamingWithCellularDataMessage", @"text label for streaming with cellular data message")
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:streamItem, nil];
    [alertView show];
}

@end
