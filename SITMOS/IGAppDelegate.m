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
#import "IGMediaPlayerAsset.h"
#import "IGAPIKeys.h"
#import "IGEpisodeImporter.h"
#import "IGEpisode.h"
#import "IGDefines.h"
//#import "TestFlight.h"

@implementation IGAppDelegate

#pragma mark - Application Lifecycle

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
//    [TestFlight takeOff:IGTestFlightAPIKey];
    
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"SITMOS.sqlite"];
    
#ifdef DEVELOPMENT_MODE
    [IGHTTPClient setDevelopmentModeEnabled:YES];
#endif
    
//    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:IGInitialSetupImportEpisodes];
//    [[NSUserDefaults standardUserDefaults] setBool:YES forKey:IGSettingPushNotifications];
    
    [self registerDefaultSettings];
    [self importEpisodesFromMediaLibrary];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(playbackStateChanged:)
                                                     name:IGMediaPlayerPlaybackStatusChangedNotification
                                                   object:nil];
    });
    
    return YES;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self.window makeKeyAndVisible];
    
    return YES;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    [mediaPlayer stop];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:IGMediaPlayerPlaybackStatusChangedNotification
                                                  object:nil];
    
    if ([self isFirstResponder])
    {
        [self resignFirstResponder];
        [[UIApplication sharedApplication] endReceivingRemoteControlEvents];
    }
    
    [MagicalRecord cleanUp];
}

#pragma mark - State Preservation and Restoration 

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder
{
    return YES;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
    // Save media player asset
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    if ([mediaPlayer asset])
    {
        [mediaPlayer.asset setShouldRestoreState:YES];
        [coder encodeObject:[mediaPlayer asset] forKey:@"IGMediaAssetCurrentlyPlaying"];
    }
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder
{
    return YES;
}

- (void)application:(UIApplication *)application didDecodeRestorableStateWithCoder:(NSCoder *)coder
{
    // Load the saved media player asset
    IGMediaPlayerAsset *asset = [coder decodeObjectForKey:@"IGMediaAssetCurrentlyPlaying"];
    if (asset)
    {
        IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
        [mediaPlayer setAsset:asset];
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

#pragma mark - Import Episodes Media Library

- (void)importEpisodesFromMediaLibrary
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([userDefaults boolForKey:IGInitialSetupImportEpisodes])
    {
        return;
    }
    
    NSArray *episodes = [IGEpisodeImporter episodesInMediaLibrary];
    if ([episodes count] > 0)
    {
        IGEpisodeImporter *importer = [[IGEpisodeImporter alloc] initWithEpisodes:episodes
                                                             destinationDirectory:[IGEpisode episodesDirectory]
                                                                 notificationView:self.window];
        [importer showAlert];
    }
    
    // An inital search for any episodes has taken place, make sure the user isn't asked again next time.
    [userDefaults setBool:YES forKey:IGInitialSetupImportEpisodes];
    [userDefaults synchronize];
}

#pragma mark - Settings

- (void)registerDefaultSettings
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (![userDefaults objectForKey:IGSettingCellularDataStreaming])
    {
        [userDefaults setBool:YES forKey:IGSettingCellularDataStreaming];
    }
    
    if (![userDefaults objectForKey:IGSettingCellularDataDownloading])
    {
        [userDefaults setBool:NO forKey:IGSettingCellularDataDownloading];
    }
    
    if (![userDefaults objectForKey:IGSettingEpisodesDelete])
    {
        [userDefaults setBool:NO forKey:IGSettingEpisodesDelete];
    }
    
    if (![userDefaults objectForKey:IGSettingUnseenBadge])
    {
        [userDefaults setBool:NO forKey:IGSettingUnseenBadge];
    }
    
    if (![userDefaults objectForKey:IGSettingSkippingForwardTime])
    {
        [userDefaults setInteger:30 forKey:IGSettingSkippingForwardTime];
    }
    
    if (![userDefaults objectForKey:IGSettingSkippingBackwardTime])
    {
        [userDefaults setInteger:30 forKey:IGSettingSkippingBackwardTime];
    }
    
    if (![userDefaults objectForKey:IGSettingPushNotifications])
    {
        [userDefaults setBool:YES forKey:IGSettingPushNotifications];
    }
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
 * The iPod controls will send these events when the app is in the background.
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
