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

#import "IGNetworkManager.h"

#import "IGAppDelegate.h"
#import "IGXMLResponseSerialization.h"
#import "IGPodcastFeedParser.h"
#import "IGDefines.h"
#import "IGAPIKeys.h"
#import "AFNetworking.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "NSDate+Helper.h"
#import "NSString+MD5.h"

#import <WindowsAzureMobileServices/WindowsAzureMobileServices.h>

NSString * const IGDevelopmentBaseURL = @"http://www.tomdiggle.com/";
NSString * const IGDevelopmentPodcastFeedURL = @"http://www.tomdiggle.com/sitmos-development-feed/sitmos-audio-feed.xml";

NSString * const IGBaseURL = @"http://www.dereksweet.com/";
NSString * const IGPodcastFeedURL = @"http://www.dereksweet.com/sitmos/sitmos.xml";

NSString * const IGPodcastFeedLastModifiedDateKey = @"PodcastFeedLastModifiedDate";

NSString * const IGWindowsAzureMobileServicesURL = @"https://sitmos.azure-mobile.net/";

static BOOL __developmentMode = NO;

static NSDictionary *deviceToken = nil;

@interface IGNetworkManager ()

@property (nonatomic, strong) NSURL *podcastFeedURL;
@property (nonatomic, strong) AFURLSessionManager *podcastFeedSessionManager;
@property (nonatomic, strong) AFURLSessionManager *downloadSessionManager;
@property (nonatomic, strong) NSDictionary *deviceToken;
@property (nonatomic, strong) MSClient *azureClient;

@end

@implementation IGNetworkManager

#pragma mark - Development Mode

+ (void)setDevelopmentModeEnabled:(BOOL)enabled
{
    __developmentMode = enabled;
}

#pragma mark - Cellular Streaming

+ (BOOL)isOnCellularNetwork
{
    return [AFNetworkReachabilityManager.sharedManager isReachableViaWWAN];
}

#pragma mark -

+ (NSString *)incompleteDownloadsDirectory
{
    static NSString *incompleteDownloadsDirectory = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *cacheDir = NSTemporaryDirectory();
        incompleteDownloadsDirectory = [cacheDir stringByAppendingPathComponent:@"Incomplete"];
        
        NSError *error = nil;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:incompleteDownloadsDirectory withIntermediateDirectories:YES attributes:nil error:&error])
        {
            NSLog(@"Failed to create episodes dir at %@, reason %@", incompleteDownloadsDirectory, [error localizedDescription]);
        }
    });
    return incompleteDownloadsDirectory;
}

#pragma mark - Download Operations

+ (NSURLSessionDownloadTask *)downloadTaskForURL:(NSURL *)url
{
    __block NSURLSessionDownloadTask *sessionTask = nil;
    
    NSArray *downloadTasks = [IGNetworkManager downloadTasks];
    [downloadTasks enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSURLSessionDownloadTask *task = (NSURLSessionDownloadTask *)obj;
        if ([[task.originalRequest URL] isEqual:url])
        {
            sessionTask = task;
            *stop = YES;
        }
    }];
    
    return sessionTask;
}

+ (NSArray *)downloadTasks
{
    IGNetworkManager *networkManager = [[IGNetworkManager alloc] init];
    return [networkManager.downloadSessionManager downloadTasks];
}

#pragma mark - Podcast Feed URL

- (NSURL *)podcastFeedURL
{
    return __developmentMode ? [NSURL URLWithString:IGDevelopmentPodcastFeedURL] : [NSURL URLWithString:IGPodcastFeedURL];
}

#pragma mark - Podcast Feed Session Manager

- (AFURLSessionManager *)podcastFeedSessionManager
{
    static AFURLSessionManager *podcastFeedSessionManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfig.HTTPMaximumConnectionsPerHost = 1;
        podcastFeedSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:sessionConfig];
        podcastFeedSessionManager.responseSerializer = [IGXMLResponseSerialization serializer];
    });
    return podcastFeedSessionManager;
}

#pragma mark - Background Download Session Manager

- (AFURLSessionManager *)downloadSessionManager
{
    static AFURLSessionManager *downloadSessionManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration backgroundSessionConfiguration:@"com.idlegeniussoftware.sitmos.networking.session.episode.download"];
        downloadSessionManager = [[AFURLSessionManager alloc] initWithSessionConfiguration:sessionConfig];
        downloadSessionManager.securityPolicy = [AFSecurityPolicy defaultPolicy];
        
        [downloadSessionManager setDidFinishEventsForBackgroundURLSessionBlock:^(NSURLSession *session) {
            IGAppDelegate *appDelegate = (IGAppDelegate *)[[UIApplication sharedApplication] delegate];
            if (appDelegate.backgroundSessionCompletionHandler) {
                void (^completionHandler)() = appDelegate.backgroundSessionCompletionHandler;
                appDelegate.backgroundSessionCompletionHandler = nil;
                completionHandler();
            }
            
            UILocalNotification *localNotification = [[UILocalNotification alloc] init];
            localNotification.alertBody = NSLocalizedString(@"AllEpisodesFinishedDownloading", nil);
            localNotification.soundName = UILocalNotificationDefaultSoundName;
            [[UIApplication sharedApplication] presentLocalNotificationNow:localNotification];
        }];
    });
    return downloadSessionManager;
}

#pragma mark - Azure Client

- (MSClient *)azureClient
{
    static MSClient *azureClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        azureClient = [MSClient clientWithApplicationURLString:IGWindowsAzureMobileServicesURL
                                                applicationKey:IGWindowsAzureAPIKey];
    });
    return azureClient;
}

#pragma mark - Push Notifications

- (void)registerPushNotificationsForDevice:(NSData *)deviceToken completion:(void (^)(NSDictionary *result, NSError *error))completion
{
    NSCharacterSet *angleBrackets = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:angleBrackets];
    
    MSTable *devicesTable = [self.azureClient tableWithName:@"devices"];
    NSDictionary *device = @{ @"deviceToken": token };
    [devicesTable insert:device completion:^(NSDictionary *item, NSError *error) {
        if (completion)
        {
            completion(item, error);
        }
        
        // Keep a copy of the deviceToken around incase the user wants to unregister from push notifications
        self.deviceToken = item;
    }];
}

- (void)unregisterPushNotificationsWithCompletion:(void (^)(NSError *error))completion
{
    if (!_deviceToken) return;
    
    MSTable *devicesTable = [self.azureClient tableWithName:@"devices"];
    [devicesTable delete:self.deviceToken completion:^(NSNumber *itemId, NSError *error) {
        if (completion)
        {
            completion(error);
        }
        
        self.deviceToken = nil;
    }];
}

#pragma mark - Syncing Podcast Feed

- (void)syncPodcastFeedWithCompletion:(void (^)(BOOL success, NSArray *feedItems, NSError *error))completion
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:self.podcastFeedURL];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDataTask *dataTask = [self.podcastFeedSessionManager dataTaskWithRequest:request completionHandler:^(NSURLResponse *response, id responseObject, NSError *error) {
        NSHTTPURLResponse *HTTPURLResponse = (NSHTTPURLResponse *)response;
        if ([self isPodcastFeedModifiedSince:[HTTPURLResponse.allHeaderFields valueForKey:@"Last-Modified"]])
        {
            [IGPodcastFeedParser PodcastFeedParserWithXMLParser:responseObject completion:^(NSArray *feedItems, NSError *error) {
                if (completion)
                {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(error ? NO : YES, feedItems, error);
                    });
                }
            }];
        }
        else
        {
            if (completion)
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(error ? NO : YES, nil, error);
                });
            }
        }
    }];
    [dataTask resume];
}

- (BOOL)isPodcastFeedModifiedSince:(NSString *)modifiedDate
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDate *feedLastRefreshed = [NSDate dateFromString:[userDefaults objectForKey:IGPodcastFeedLastModifiedDateKey]
                                            withFormat:IGDateFormatString];
    NSDate *feedLastModified = [NSDate dateFromString:modifiedDate
                                           withFormat:IGDateFormatString];
    
    if (!feedLastRefreshed || ([feedLastRefreshed compare:feedLastModified] == NSOrderedAscending))
    {
        [userDefaults setObject:[NSDate stringFromDate:[NSDate date] withFormat:IGDateFormatString]
                         forKey:IGPodcastFeedLastModifiedDateKey];
        [userDefaults synchronize];
        return YES;
    }
    
    return NO;
}

#pragma mark - Download Episode

- (void)downloadEpisodeWithDownloadURL:(NSURL *)downloadURL destinationURL:(NSURL *)destinationURL completion:(void (^)(BOOL success, NSError *error))completion
{
    NSData *resumeData = [self loadResumeDataForDownloadURL:downloadURL];
    if (resumeData)
    {
        [self downloadEpisodeWithResumeData:resumeData downloadURL:downloadURL destinationURL:destinationURL completion:completion];
        
        return;
    }
    
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:downloadURL];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    NSURLSessionDownloadTask *downloadTask = [self.downloadSessionManager downloadTaskWithRequest:request progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        
        return destinationURL;
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (error)
        {
            NSData *resumeData = [[error userInfo] objectForKey:NSURLSessionDownloadTaskResumeData];
            [self saveResumableData:resumeData withFileName:[NSString MD5Hash:[downloadURL absoluteString]]];
        }
        
        if (completion)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error ? NO : YES, error);
            });
        }
    }];
    [downloadTask resume];
}

- (void)downloadEpisodeWithResumeData:(NSData *)resumeData downloadURL:(NSURL *)downloadURL destinationURL:(NSURL *)destinationURL completion:(void (^)(BOOL success, NSError *error))completion
{
    NSURLSessionDownloadTask *downloadTask = [self.downloadSessionManager downloadTaskWithResumeData:resumeData progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
        
        return destinationURL;
    } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
        if (error)
        {
            NSData *resumeData = [[error userInfo] objectForKey:NSURLSessionDownloadTaskResumeData];
            [self saveResumableData:resumeData withFileName:[NSString MD5Hash:[downloadURL absoluteString]]];
        }
        
        if (completion)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                completion(error ? NO : YES, error);
            });
        }
    }];
    [downloadTask resume];
}

- (void)saveResumableData:(NSData *)data withFileName:(NSString *)fileName
{
    if (!data || !fileName)
    {
        return;
    }
    
    NSString *resumeDataPath = [[IGNetworkManager incompleteDownloadsDirectory] stringByAppendingPathComponent:fileName];
    [[NSFileManager defaultManager] createFileAtPath:resumeDataPath contents:data attributes:nil];
}

- (NSData *)loadResumeDataForDownloadURL:(NSURL *)downloadURL
{
    if (!downloadURL)
    {
        return nil;
    }
    
    NSString *fileName = [NSString MD5Hash:[downloadURL absoluteString]];
    NSString *resumeDataPath = [[IGNetworkManager incompleteDownloadsDirectory] stringByAppendingPathComponent:fileName];
    if ([[NSFileManager defaultManager] fileExistsAtPath:resumeDataPath])
    {
        return [NSData dataWithContentsOfFile:resumeDataPath];
    }
    
    return nil;
}

@end
