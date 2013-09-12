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

#import "IGHTTPClient.h"

#import "IGPodcastFeedParser.h"
#import "IGEpisode.h"
#import "IGDefines.h"
#import "IGAPIKeys.h"
#import "UIApplication+LocalNotificationHelper.h"
#import "NSDate+Helper.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFXMLRequestOperation.h"
#import "AFDownloadRequestOperation.h"

#import <WindowsAzureMobileServices/WindowsAzureMobileServices.h>

NSString * const IGDevelopmentBaseURL = @"http://www.tomdiggle.com/";
NSString * const IGDevelopmentAudioPodcastFeedURL = @"http://www.tomdiggle.com/sitmos-development-feed/sitmos-audio-feed.xml";
NSString * const IGDevelopmentVideoPodcastFeedURL = @"http://www.tomdiggle.com/sitmos-development-feed/sitmos-video-feed.xml";

NSString * const IGBaseURL = @"http://www.dereksweet.com/";
NSString * const IGAudioPodcastFeedURL = @"http://www.dereksweet.com/sitmos/sitmos.xml";
NSString * const IGVideoPodcastFeedURL = @"http://www.dereksweet.com/sitmos/sitmos-video-feed.xml";

NSString * const IGHTTPClientCurrentDownloadRequests = @"IGHTTPClientCurrentDownloadRequests";

NSString * const IGAudioPodcastFeedLastModifiedKey = @"IGAudioPodcastFeedLastModifiedKey";
NSString * const IGVideoPodcastFeedLastModifiedKey = @"IGVideoPodcastFeedLastModifiedKey";

NSString * const IGWindowsAzureMobileServicesURL = @"https://sitmos.azure-mobile.net/";

static BOOL __developmentMode = NO;

@interface IGHTTPClient ()

@property (nonatomic, strong) NSDictionary *deviceToken;
@property (nonatomic, strong) NSURL *audioPodcastFeedURL;
@property (nonatomic, strong) NSURL *videoPodcastFeedURL;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong, readwrite) NSMutableArray *currentDownloadRequests;
@property (nonatomic, strong) MSClient *azureClient;

@end

@implementation IGHTTPClient

#pragma mark - Class Methods

+ (IGHTTPClient *)sharedClient
{
    static IGHTTPClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[self alloc] init];
    });
    return sharedClient;
}

#pragma mark - Cellular Streaming

+ (BOOL)allowCellularDataStreaming
{
    BOOL allowCellularDataStreaming = [[NSUserDefaults standardUserDefaults] boolForKey:IGSettingCellularDataStreaming];
    AFNetworkReachabilityStatus networkReachabilityStatus = [[IGHTTPClient sharedClient] networkReachabilityStatus];
    if (!allowCellularDataStreaming && networkReachabilityStatus != AFNetworkReachabilityStatusReachableViaWiFi)
    {
        return NO;
    }
    
    return YES;
}

+ (BOOL)allowCellularDataDownloading
{
    BOOL allowCellularDataDownloading = [[NSUserDefaults standardUserDefaults] boolForKey:IGSettingCellularDataDownloading];
    AFNetworkReachabilityStatus networkReachabilityStatus = [[IGHTTPClient sharedClient] networkReachabilityStatus];
    if (!allowCellularDataDownloading && networkReachabilityStatus != AFNetworkReachabilityStatusReachableViaWiFi)
    {
        return NO;
    }
    
    return YES;
}

#pragma mark - Development Mode

+ (void)setDevelopmentModeEnabled:(BOOL)enabled
{
    __developmentMode = enabled;
}

#pragma mark - Initializers

- (id)init
{
    NSURL *baseURL = nil;
    if (__developmentMode)
    {
        baseURL = [NSURL URLWithString:IGDevelopmentBaseURL];
        _audioPodcastFeedURL = [NSURL URLWithString:IGDevelopmentAudioPodcastFeedURL];
        _videoPodcastFeedURL = [NSURL URLWithString:IGDevelopmentVideoPodcastFeedURL];
    }
    else
    {
        baseURL = [NSURL URLWithString:IGBaseURL];
        _audioPodcastFeedURL = [NSURL URLWithString:IGAudioPodcastFeedURL];
        _videoPodcastFeedURL = [NSURL URLWithString:IGDevelopmentVideoPodcastFeedURL];
    }
    
    if ((self = [super initWithBaseURL:baseURL]))
    {
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
        _callbackQueue = dispatch_queue_create("com.IdleGeniusSoftware.SITMOS.network-callback-queue", NULL);
        _currentDownloadRequests = [NSMutableArray arrayWithArray:[self currentDownloadRequests]];
        _azureClient = [MSClient clientWithApplicationURLString:IGWindowsAzureMobileServicesURL
                                                 applicationKey:IGWindowsAzureAPIKey];
    }
    
    return self;
}

#pragma mark - AFHTTPClient

- (NSMutableURLRequest *)requestWithURL:(NSURL *)url
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    [request setTimeoutInterval:10];
	return request;
}

- (void)enqueueHTTPRequestOperation:(AFHTTPRequestOperation *)operation
{
    operation.completionQueue = self.callbackQueue;
	[super enqueueHTTPRequestOperation:operation];
}

#pragma mark - Push Notifications

- (void)registerPushNotificationsForDevice:(NSData *)deviceToken completion:(void (^)(NSDictionary *result, NSError *error))completion
{
    NSCharacterSet *angleBrackets = [NSCharacterSet characterSetWithCharactersInString:@"<>"];
    NSString *token = [[deviceToken description] stringByTrimmingCharactersInSet:angleBrackets];
    
    MSTable *devicesTable = [_azureClient tableWithName:@"devices"];
    NSDictionary *device = @{ @"deviceToken": token };
    [devicesTable insert:device completion:^(NSDictionary *item, NSError *error) {
        if (completion)
        {
            completion(item, error);
        }
        
        // Keep a copy of the deviceToken around incase the user wants to unregister from push notifications
        _deviceToken = item;
    }];
}

- (void)unregisterPushNotificationsWithCompletion:(void (^)(NSError *error))completion
{
    if (!_deviceToken) return;
    
    MSTable *devicesTable = [_azureClient tableWithName:@"devices"];
    [devicesTable delete:_deviceToken completion:^(NSNumber *itemId, NSError *error) {
        if (completion)
        {
            completion(error);
        }
        
        _deviceToken = nil;
    }];
}

#pragma mark - Syncing Podcast Feeds

- (void)syncPodcastFeedsWithCompletion:(void (^)(BOOL success, NSError *error))completion
{
    [self enqueueBatchOfHTTPRequestOperations:[self podcastFeedRequestOperations] progressBlock:nil completionBlock:^(NSArray *operations) {
        NSMutableArray *podcastFeedItems = [[NSMutableArray alloc] init];
        [operations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            AFXMLRequestOperation *operation = obj;
            if ([operation error])
            {
               if (completion)
               {
                   completion(NO, [operation error]);
                   *stop = YES;
               }
            }
            else
            {
                NSXMLParser *xml = [[NSXMLParser alloc] initWithData:operation.responseData];
                [IGPodcastFeedParser PodcastFeedParserWithXMLParser:xml completion:^(NSArray *feedItems, NSError *error) {
                    if (error)
                    {
                        if (completion)
                        {
                            completion(NO, error);
                            *stop = YES;
                        }
                    }
                    else
                    {
                        NSHTTPURLResponse *response = (NSHTTPURLResponse *)[obj response];
                        if ([self isPodcastFeed:[[operation request] URL] modifiedSince:[[response allHeaderFields] valueForKey:@"Last-Modified"]])
                        {
                            [podcastFeedItems addObjectsFromArray:feedItems];
                        }
                    }
                }];
            }
        }];
        
        [IGEpisode importPodcastFeedItems:podcastFeedItems completion:^(BOOL success, NSError *error) {
            if (!success && error)
            {
                completion(NO, error);
            }
            else if (completion)
            {
                completion(YES, nil);
            }
        }];
    }];
}

- (NSArray *)podcastFeedRequestOperations
{
    NSURLRequest *audioFeedRequest = [self requestWithURL:_audioPodcastFeedURL];
    AFXMLRequestOperation *audioFeedOperation = [[AFXMLRequestOperation alloc] initWithRequest:audioFeedRequest];
    
    NSURLRequest *videoFeedRequest = [self requestWithURL:_videoPodcastFeedURL];
    AFXMLRequestOperation *videoFeedOperation = [[AFXMLRequestOperation alloc] initWithRequest:videoFeedRequest];
    
    return @[audioFeedOperation, videoFeedOperation];
}

- (BOOL)isPodcastFeed:(NSURL *)feedURL modifiedSince:(NSString *)modifiedDate
{
    NSString *key = ([feedURL isEqual:_audioPodcastFeedURL]) ? IGAudioPodcastFeedLastModifiedKey : IGVideoPodcastFeedLastModifiedKey;
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDate *feedLastRefreshed = [NSDate dateFromString:[userDefaults objectForKey:key]
                                            withFormat:IGEpisodeDateFormat];
    NSDate *feedLastModified = [NSDate dateFromString:modifiedDate
                                           withFormat:IGEpisodeDateFormat];
    
    if (!feedLastRefreshed || ([feedLastRefreshed compare:feedLastModified] == NSOrderedAscending))
    {
        [userDefaults setObject:[NSDate stringFromDate:[NSDate date] withFormat:IGEpisodeDateFormat]
                         forKey:key];
        [userDefaults synchronize];
        return YES;
    }
    
    return NO;
}

#pragma mark - Downloading Episode

- (void)downloadEpisodeWithURL:(NSURL *)downloadURL targetPath:(NSURL *)targetPath completion:(void (^)(BOOL success, NSError *error))completion
{
    [self addDownloadRequest:downloadURL
                  targetPath:targetPath];
    
    NSMutableURLRequest *request = [self requestWithURL:downloadURL];
    AFDownloadRequestOperation *operation = [[AFDownloadRequestOperation alloc] initWithRequest:request
                                                                                     targetPath:[targetPath path]
                                                                                   shouldResume:YES];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        if (completion)
        {
            completion(YES, nil);
        }
        
        [self removeDownloadRequest:downloadURL
                         targetPath:targetPath];
        
        NSDictionary *parameters = @{ @"alertBody" : NSLocalizedString(@"EpisodeDownloadFinished", @"text label for all episodes finished downloading"),
                                      @"soundName" : UILocalNotificationDefaultSoundName };
        [UIApplication presentLocalNotificationNowWithParameters:parameters];
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        if (completion)
        {
            completion(NO, error);
        }
        
        [self removeDownloadRequest:downloadURL
                         targetPath:targetPath];
        
        NSDictionary *parameters = @{ @"alertBody" : NSLocalizedString(@"EpisodeDownloadFailed", @"text label for all episodes failed to download"),
                                      @"soundName" : UILocalNotificationDefaultSoundName };
        [UIApplication presentLocalNotificationNowWithParameters:parameters];
    }];
    
    [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:^{
        NSDictionary *parameters = @{ @"alertBody" : NSLocalizedString(@"AllDownloadsPaused", @"text label for all downloads paused"),
                                      @"soundName" : UILocalNotificationDefaultSoundName };
        [UIApplication presentLocalNotificationNowWithParameters:parameters];
    }];
    
    [self enqueueHTTPRequestOperation:operation];
}

#pragma mark - Download Operations

- (AFDownloadRequestOperation *)requestOperationForURL:(NSURL *)url
{
    __block AFDownloadRequestOperation *requestOperation = nil;
    NSArray *downloadOperations = [[self operationQueue] operations];
    [downloadOperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[obj class] isSubclassOfClass:[AFDownloadRequestOperation class]])
        {
            if ([[[obj request] URL] isEqual:url])
            {
                requestOperation = obj;
                *stop = YES;
            }
        }
    }];
    
    return requestOperation;
}

#pragma mark - Current Download Requests

- (NSArray *)currentDownloadRequests
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if (![userDefaults objectForKey:IGHTTPClientCurrentDownloadRequests])
    {
        [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:[NSArray array]]
                         forKey:IGHTTPClientCurrentDownloadRequests];
        [userDefaults synchronize];
    }
    
    NSData *data = [userDefaults objectForKey:IGHTTPClientCurrentDownloadRequests];
    NSArray *requests = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    return requests;
}

- (void)saveCurrentDownloadRequests
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:_currentDownloadRequests]
                     forKey:IGHTTPClientCurrentDownloadRequests];
    [userDefaults synchronize];
}

- (void)addDownloadRequest:(NSURL *)downloadURL targetPath:(NSURL *)targetPath
{
    NSArray *request = @[downloadURL, targetPath];
    if (![_currentDownloadRequests containsObject:request])
    {
        [_currentDownloadRequests addObject:request];
        [self saveCurrentDownloadRequests];
    }
}

- (void)removeDownloadRequest:(NSURL *)downloadURL targetPath:(NSURL *)targetPath
{
    NSArray *request = @[downloadURL, targetPath];
    if ([_currentDownloadRequests containsObject:request])
    {
        [_currentDownloadRequests removeObject:request];
        [self saveCurrentDownloadRequests];
    }
}

@end
