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

@class IGRSSXMLRequestOperation;

extern NSString * const IGHTTPClientNetworkErrorDomain;

typedef enum {
    IGHTTPClientNetworkErrorCellularDataDownloadingNotAllowed
} IGHTTPClientNetworkError;

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

#pragma mark - Syncing Podcast Feed

/**
 * @name Syncing Podcast Feed
 */

/**
 * Syncs the podcast feed and executes a handler block when the request successful or fails.
 *
 * @param The success handler block to execute.
 * @param The failure handler block to execute.
 */
- (void)syncPodcastFeedWithSuccess:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure;

#pragma mark - Downloading Episode

/**
 * @name Downloading Episode
 */

/**
 * Starts downloading the episode from the downloadURL parameter and saves to the saveToURL parameter. While download is in progress the downloadProgress handler block is executed, if download is successful the success handler block is executed or if download fails the failure handler block is executed. The download operation is added to the downloadRequestOperations array and removed if download is successful or fails.
 *
 * @param The URL to download the episode from.
 * @param The URL to save the download to.
 * @param The success handler block to execute.
 * @param The failure handler block to execute.
 */
- (void)downloadEpisodeWithURL:(NSURL *)downloadURL
                    targetPath:(NSURL *)targetPath
                       success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                       failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure;

/**
 * Returns an array of the current download operations.
 *
 * @return The current download operations. Returns nil if there are none.
 */
- (NSArray *)downloadOperations;

/**
 * Returns the AFHTTPRequestOperation for the given URL.
 *
 * @return The request operation. Returns nil if a request operation is not found.
 */
- (AFHTTPRequestOperation *)requestOperationForURL:(NSURL *)url;

@end
