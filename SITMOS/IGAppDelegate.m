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

#import "IGAppDelegate.h"
#import "IGTestFlight.h"
#import "IGEpisode.h"
#import "IGInitialSetup.h"

@implementation IGAppDelegate

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TestFlight takeOff:IGTestFlightTeamToken];
    
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"SITMOS.sqlite"];
    
    [self applyStylesheet];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([IGEpisode MR_countOfEntities] == 0)
        {
            // Run the initial setup only if no entites exist
            [IGInitialSetup runInitialSetup];
        }
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackStateChanged:)
                                                     name:IGMediaPlayerPlaybackStatusChangedNotification
                                                   object:nil];
    });
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{

}

- (void)applicationDidEnterBackground:(UIApplication *)application
{

}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
 
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [MagicalRecord cleanUp];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IGMediaPlayerPlaybackStatusChangedNotification
                                                  object:nil];
    
    if ([self isFirstResponder])
    {
        [self resignFirstResponder];
        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    }
}

#pragma mark - Stylesheet

- (void)applyStylesheet
{
    [[UINavigationBar appearance] setBackgroundImage:[[UIImage imageNamed:@"nav-bar-bg"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10.0f, 0, 10.0f)]
                                       forBarMetrics:UIBarMetricsDefault];
    
    [[UISearchBar appearance] setBackgroundImage:[UIImage imageNamed:@"search-bar-bg"]];
    
    UIBarButtonItem *barButton = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationBar class], nil];
    [barButton setBackgroundImage:[[UIImage imageNamed:@"nav-button"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6.0f, 0, 6.0f)]
                         forState:UIControlStateNormal
                       barMetrics:UIBarMetricsDefault];
	[barButton setBackgroundImage:[[UIImage imageNamed:@"nav-button-highlighted"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6.0f, 0, 6.0f)]
                         forState:UIControlStateHighlighted
                       barMetrics:UIBarMetricsDefault];
    
	[barButton setBackButtonBackgroundImage:[[UIImage imageNamed:@"nav-back-button"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13.0f, 0, 5.0f)]
                                   forState:UIControlStateNormal
                                 barMetrics:UIBarMetricsDefault];
    [barButton setBackButtonBackgroundImage:[[UIImage imageNamed:@"nav-back-button-highlighted"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13.0f, 0, 5.0f)]
                                   forState:UIControlStateHighlighted
                                 barMetrics:UIBarMetricsDefault];

}

#pragma mark - Managing the Responder Chain

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

#pragma mark - Playback State Changed

/**
 If the playback state changes to play and the app delegate is not already the 
 first responder begin receiving remote control events and become the first 
 responder.
 */
- (void)playbackStateChanged:(NSNotification *)notification
{
    if ([self isFirstResponder]) return;
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

#pragma mark - Remote Control Events

/**
 The iPod controls will send these events when the app is in the background
 */
- (void)remoteControlReceivedWithEvent:(UIEvent *)event 
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
	switch (event.subtype) 
    {
        case UIEventSubtypeRemoteControlPlay:
			[mediaPlayer play];
			break;
        case UIEventSubtypeRemoteControlPause:
			[mediaPlayer pause];
			break;
		case UIEventSubtypeRemoteControlStop:
			[mediaPlayer pause];
			break;
		case UIEventSubtypeRemoteControlTogglePlayPause:
            [mediaPlayer isPaused] ? [mediaPlayer play] : [mediaPlayer pause];
			break;
		case UIEventSubtypeRemoteControlNextTrack:
            [mediaPlayer playNextEpisode];
            break;
        case UIEventSubtypeRemoteControlPreviousTrack:
            [mediaPlayer playPreviousEpisode];
            break;
        case UIEventSubtypeRemoteControlBeginSeekingBackward:
            [mediaPlayer beginSeekingBackward];
            break;
        case UIEventSubtypeRemoteControlEndSeekingBackward:
            [mediaPlayer endSeeking];
            break;
        case UIEventSubtypeRemoteControlBeginSeekingForward:
            [mediaPlayer beginSeekingForward];
            break;
        case UIEventSubtypeRemoteControlEndSeekingForward:
            [mediaPlayer endSeeking];
            break;
		default:
			break;
	}
}

@end
