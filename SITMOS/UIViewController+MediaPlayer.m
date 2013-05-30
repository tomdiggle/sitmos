/**
 * Copyright (c) 2013, Tom Diggle
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

#import "UIViewController+MediaPlayer.h"

#import "IGMediaPlayer.h"
#import "IGMediaPlayerAsset.h"
#import "IGHTTPClient.h"
#import "IGMediaPlayerViewController.h"
#import "UIAlertView+Blocks.h"
#import "RIButtonItem.h"

@implementation UIViewController (MediaPlayer)

#pragma mark - Showing Media Player

- (void)showMediaPlayerWithAsset:(IGMediaPlayerAsset *)asset
{
    if (![[asset contentURL] isFileURL] && ![IGHTTPClient allowCellularDataStreaming])
    {
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", "text label for cancel")];
        RIButtonItem *streamItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Stream", @"text label for stream")];
        streamItem.action = ^{
            [self presentMediaPlayerWithAsset:asset];
        };
        
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"StreamingWithCellularDataTitle", @"text label for streaming with cellular data title")
                                                            message:NSLocalizedString(@"StreamingWithCellularDataMessage", @"text label for streaming with cellular data message")
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:streamItem, nil];
        [alertView show];
    }
    else
    {
        [self presentMediaPlayerWithAsset:asset];
    }
}

- (void)presentMediaPlayerWithAsset:(IGMediaPlayerAsset *)asset
{
    IGMediaPlayerViewController *mediaPlayerViewController = [[IGMediaPlayerViewController alloc] initWithMediaPlayerAsset:asset];
    UINavigationController *mediaPlayerNavigationController = [[UINavigationController alloc] initWithRootViewController:mediaPlayerViewController];
    [[self navigationController] presentViewController:mediaPlayerNavigationController
                                              animated:YES
                                            completion:nil];
}

#pragma mark - Now Playing Button

- (void)displayNowPlayingButon
{
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"show-audio-player-icon"]
                                                                              style:UIBarButtonItemStyleBordered
                                                                             target:self
                                                                             action:@selector(nowPlayingButtonTapped:)];
}

- (void)hideNowPlayingButton:(BOOL)animated
{
    [[self navigationItem] setRightBarButtonItem:nil
                                        animated:animated];
}

- (void)nowPlayingButtonTapped:(id)sender
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    [self presentMediaPlayerWithAsset:[mediaPlayer asset]];
}

@end
