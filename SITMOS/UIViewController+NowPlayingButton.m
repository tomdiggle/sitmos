//
//  UIViewController+NowPlayingButton.m
//  SITMOS
//
//  Created by Tom Diggle on 05/03/2013.
//
//

#import "UIViewController+NowPlayingButton.h"
#import "IGAudioPlayerViewController.h"
#import "IGMediaPlayer.h"
#import "IGMediaPlayerAsset.h"

@implementation UIViewController (NowPlayingButton)

- (void)showNowPlayingButon:(BOOL)show
{
    if (show)
    {
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemPlay
                                                                                               target:self
                                                                                               action:@selector(nowPlayingButtonTapped:)];
    }
    else
    {
        [[self navigationItem] setRightBarButtonItem:nil
                                            animated:YES];
    }
}

- (void)nowPlayingButtonTapped:(id)sender
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    
    IGAudioPlayerViewController *audioPlayerViewController = [[self storyboard] instantiateViewControllerWithIdentifier:@"IGAudioPlayerViewController"];
    [audioPlayerViewController setTitle:[[mediaPlayer asset] title]];
    
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"nav-back-arrow"]
                                                                             style:UIBarButtonItemStyleBordered
                                                                            target:nil
                                                                            action:nil];
    
    [[self navigationController] pushViewController:audioPlayerViewController
                                           animated:YES];
}

@end
