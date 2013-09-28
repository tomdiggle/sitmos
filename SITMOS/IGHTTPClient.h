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

#import "AFHTTPClient.h"

#import <Foundation/Foundation.h>

@class AFDownloadRequestOperation;

extern NSString * const IGDevelopmentBaseURL;
extern NSString * const IGDevelopmentPodcastFeedURL;

extern NSString * const IGBaseURL;
extern NSString * const IGPodcastFeedURL;

/**
 * The IGHTTPClient class provides a centralized point of control for network connections.
 *
 * You can access this object by invoking the sharedClient class method.
 *
 *      IGHTTPClient *sharedClient = [IGHTTPClient sharedClient];
 */

@interface IGHTTPClient : AFHTTPClient

/**
 * Returns an array of all the current download requests.
 */
@property (nonatomic, strong, readonly) NSMutableArray *currentDownloadRequests;

#pragma mark - Getting the HTTP Client Instance

/**
 * @name Getting the HTTP Client Instance
 */

/**
 * Returns the singleton HTTP client instance.
 *
 * @return The HTTP client instance.
 */
+ (IGHTTPClient *)sharedClient;

#pragma mark - Cellular Streaming

/**
 * @name Cellular Streaming
 */

/**
 * @return YES if cellular data streaming is allowed, NO otherwise.
 */
+ (BOOL)allowCellularDataStreaming;

/**
 * @return YES if cellular data downloading is allowed, NO otherwise.
 */
+ (BOOL)allowCellularDataDownloading;

#pragma mark - Development Mode

/**
 * @name Development Mode
 */

/**
 * When enabling development mode the development podcast feeds will be used. 
 *
 * @see IGDevelopmentBaseURL
 * @see IGDevelopmentAudioPodcastFeedURL
 * @see IGDevelopmentVideoPodcastFeedURL
 */
+ (void)setDevelopmentModeEnabled:(BOOL)enabled;

#pragma mark - Push Notifications

/**
 * @name Push Notifications
 */

/**
 * Registers device to receive push notifications.
 *
 * @param A token that identifies the device to Apple Push Notification Service (APNS).
 * @param The completion handler block to execute.
 */
- (void)registerPushNotificationsForDevice:(NSData *)deviceToken completion:(void (^)(NSDictionary *result, NSError *error))completion;

/**
 * Unregisters a device from receiving push notifications.
 *
 * @param The completion handler block to execute.
 */
- (void)unregisterPushNotificationsWithCompletion:(void (^)(NSError *error))completion;

#pragma mark - Syncing Podcast Feed

/**
 * @name Syncing Podcast Feed
 */

/**
 * Syncs the podcast feed and executes a handler block when complete.
 *
 * @param The completion handler block to execute.
 */
- (void)syncPodcastFeedWithCompletion:(void (^)(BOOL success, NSArray *feedItems, NSError *error))completion;

#pragma mark - Downloading Episode

/**
 * @name Downloading Episode
 */

/**
 * Starts downloading the episode from the downloadURL parameter and saves to the targetPath parameter. A completion block is fired and a local notification is posted when download succeeds or fails.
 *
 * @param The URL to download the episode from.
 * @param The URL to save the download to.
 * @param The completion handler block to execute.
 */
- (void)downloadEpisodeWithURL:(NSURL *)downloadURL
                    targetPath:(NSURL *)targetPath
                    completion:(void (^)(BOOL success, NSError *error))completion;

/**
 * Returns the AFDownloadRequestOperation for the given URL.
 *
 * @return The request operation. Returns nil if a request operation is not found.
 */
- (AFDownloadRequestOperation *)requestOperationForURL:(NSURL *)url;

@end
