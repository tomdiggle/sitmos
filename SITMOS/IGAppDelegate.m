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

#import "IGHTTPClient.h"
#import "IGMediaPlayer.h"
#import "IGAPIKeys.h"
#import "IGInitialSetup.h"
#import "IGDefines.h"
#import "TDNotificationPanel.h"
#import "TestFlight.h"
#import "CoreData+MagicalRecord.h"

@implementation IGAppDelegate

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [TestFlight takeOff:IGTestFlightAPIKey];
    
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"SITMOS.sqlite"];
    
#ifdef DEVELOPMENT_MODE
    [IGHTTPClient setDevelopmentModeEnabled:YES];
#endif
    
    [self applyStylesheet];
    
//    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:IGInitialSetupImportEpisodes];
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:IGSettingPushNotifications];
    
    [self initialSetup];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackStateChanged:)
                                                     name:IGMediaPlayerPlaybackStatusChangedNotification
                                                   object:nil];
    });
    
    return YES;
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

#pragma mark - Orientation Support

- (NSUInteger)application:(UIApplication *)application supportedInterfaceOrientationsForWindow:(UIWindow *)window
{
    if ([[window rootViewController] isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *nc = (UINavigationController *)window.rootViewController;
        return ([[nc visibleViewController] supportedInterfaceOrientations] != 0 ? [[nc visibleViewController] supportedInterfaceOrientations] : UIInterfaceOrientationMaskPortrait);
    }
    
    return UIInterfaceOrientationMaskPortrait;
}

#pragma mark - Stylesheet

- (void)applyStylesheet
{
    [[UISearchBar appearance] setBackgroundImage:[UIImage imageNamed:@"search-bar-bg"]];
    
    UINavigationBar *navigationBar = [UINavigationBar appearanceWhenContainedIn:[UINavigationController class], nil];
    [navigationBar setBackgroundImage:[[UIImage imageNamed:@"nav-bar-port-bg"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10.0f, 0, 10.0f)]
                        forBarMetrics:UIBarMetricsDefault];
    [navigationBar setBackgroundImage:[[UIImage imageNamed:@"nav-bar-land-bg"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 10.0f, 0, 10.0f)]
                        forBarMetrics:UIBarMetricsLandscapePhone];
    
    UIBarButtonItem *barButton = [UIBarButtonItem appearanceWhenContainedIn:[UINavigationController class], nil];
    [barButton setBackgroundImage:[[UIImage imageNamed:@"nav-button-port"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6.0f, 0, 6.0f)]
                         forState:UIControlStateNormal
                       barMetrics:UIBarMetricsDefault];
	[barButton setBackgroundImage:[[UIImage imageNamed:@"nav-button-port-highlighted"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6.0f, 0, 6.0f)]
                         forState:UIControlStateHighlighted
                       barMetrics:UIBarMetricsDefault];
    [barButton setBackgroundImage:[[UIImage imageNamed:@"nav-button-land"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6.0f, 0, 6.0f)]
                         forState:UIControlStateNormal
                       barMetrics:UIBarMetricsLandscapePhone];
    [barButton setBackgroundImage:[[UIImage imageNamed:@"nav-button-land-highlighted"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 6.0f, 0, 6.0f)]
                         forState:UIControlStateNormal
                       barMetrics:UIBarMetricsLandscapePhone];
    
    // Nav back button
	[barButton setBackButtonBackgroundImage:[[UIImage imageNamed:@"nav-back-button-port"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13.0f, 0, 5.0f)]
                                   forState:UIControlStateNormal
                                 barMetrics:UIBarMetricsDefault];
    [barButton setBackButtonBackgroundImage:[[UIImage imageNamed:@"nav-back-button-port-highlighted"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13.0f, 0, 5.0f)]
                                   forState:UIControlStateHighlighted
                                 barMetrics:UIBarMetricsDefault];
    [barButton setBackButtonBackgroundImage:[[UIImage imageNamed:@"nav-back-button-land"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13.0f, 0, 5.0f)]
                                   forState:UIControlStateNormal
                                 barMetrics:UIBarMetricsLandscapePhone];
    [barButton setBackButtonBackgroundImage:[[UIImage imageNamed:@"nav-back-button-land-highlighted"] resizableImageWithCapInsets:UIEdgeInsetsMake(0, 13.0f, 0, 5.0f)]
                                   forState:UIControlStateHighlighted
                                 barMetrics:UIBarMetricsLandscapePhone];
}

#pragma mark - Push Notifications

- (void)registerForPushNotifications
{
    if ([[NSUserDefaults standardUserDefaults] boolForKey:IGSettingPushNotifications])
    {
        NSLog(@"Registering for remote notifications");
        [[UIApplication sharedApplication] registerForRemoteNotificationTypes:(UIRemoteNotificationTypeBadge | UIRemoteNotificationTypeSound | UIRemoteNotificationTypeAlert)];
    }
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken
{
    NSLog(@"didRegisterForRemoteNotificationsWithDeviceToken:");
    IGHTTPClient *httpClient = [IGHTTPClient sharedClient];
    [httpClient registerPushNotificationsForDevice:deviceToken completion:nil];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error
{
    // handle error
    NSLog(@"Registering device for push notifications failed: %@", error);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)remoteNotification
{
    NSLog(@"Remote Notifications received: %@", remoteNotification);
}

#pragma mark - Initial Setup

- (void)initialSetup
{
    [IGInitialSetup runInitialSetupWithCompletion:^(NSUInteger episodesImported, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (episodesImported > 0)
            {
                [TDNotificationPanel showNotificationInView:self.window
                                                      title:[NSString stringWithFormat:NSLocalizedString(@"SuccessfullyImportedEpisodes", @"text label for successfully imported episodes"), episodesImported]
                                                   subtitle:nil
                                                       type:TDNotificationTypeSuccess
                                                       mode:TDNotificationModeText
                                                dismissable:YES
                                             hideAfterDelay:4];
            }
            else if (error)
            {
                [TDNotificationPanel showNotificationInView:self.window
                                                      title:NSLocalizedString(@"ErrorImportingEpisodes", @"text label for error importing episodes")
                                                   subtitle:nil
                                                       type:TDNotificationTypeError
                                                       mode:TDNotificationModeText
                                                dismissable:YES
                                             hideAfterDelay:4];
            }
            
            // Register for push notifications after importing episodes. This is to avoid displaying two alert's when user first launches app.
            [self registerForPushNotifications];
        });
    }];
}

#pragma mark - Managing the Responder Chain

- (BOOL)canBecomeFirstResponder
{
    return YES;
}

#pragma mark - Playback State Changed

/**
 * If the playback state changes to play and the app delegate is not already the first responder begin receiving remote control events and become the first responder.
 */
- (void)playbackStateChanged:(NSNotification *)notification
{
    if ([self isFirstResponder]) return;
    
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    [self becomeFirstResponder];
}

#pragma mark - Remote Control Events

/**
 * The iPod controls will send these events when the app is in the background
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
        {
            NSUInteger skipForwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingForwardTime];
            [mediaPlayer seekToTime:[mediaPlayer currentTime] + (float)skipForwardTime];
            
            break;
        }
        case UIEventSubtypeRemoteControlPreviousTrack:
        {
            NSUInteger skipBackwardTime = [[NSUserDefaults standardUserDefaults] integerForKey:IGSettingSkippingBackwardTime];
            [mediaPlayer seekToTime:[mediaPlayer currentTime] - (float)skipBackwardTime];
            
            break;
        }
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
