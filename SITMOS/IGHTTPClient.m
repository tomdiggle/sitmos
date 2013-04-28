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

#import "IGRSSXMLRequestOperation.h"
#import "IGPodcastFeedParser.h"
#import "IGEpisode.h"
#import "IGDefines.h"
#import "NSDate+Helper.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFDownloadRequestOperation.h"

NSString * const IGHTTPClientNetworkErrorDomain = @"IGHTTPClientNetworkErrorDomain";
NSString * const IGHTTPClientCurrentDownloadRequests = @"IGHTTPClientCurrentDownloadRequests";

@interface IGHTTPClient ()

@property (nonatomic, strong) NSURL *audioFeedURL;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong, readwrite) NSMutableArray *currentDownloadRequests;

@end

@implementation IGHTTPClient

#pragma mark - Class Methods

+ (IGHTTPClient *)sharedClient {
    static IGHTTPClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[self alloc] init];
    });
    return sharedClient;
}

#pragma mark - Initializers

- (id)init {
    NSURL *baseURL = nil;
#ifdef DEVELOPMENT
    baseURL = [NSURL URLWithString:@"http://www.tomdiggle.com/"];
    _audioFeedURL = [NSURL URLWithString:@"http://www.tomdiggle.com/sitmos-test-feed/sitmos-audio-feed.xml"];
#else
    baseURL = [NSURL URLWithString:@"http://www.dereksweet.com/"];
    _audioFeedURL = [NSURL URLWithString:@"http://www.dereksweet.com/sitmos/sitmos.xml"];
#endif
    
    if ((self = [super initWithBaseURL:baseURL])) {
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
        _callbackQueue = dispatch_queue_create("com.IdleGeniusSoftware.SITMOS.network-callback-queue", NULL);
        
        _currentDownloadRequests = [NSMutableArray arrayWithArray:[self currentDownloadRequests]];
    }
    
    return self;
}

#pragma mark - AFHTTPClient

- (NSMutableURLRequest *)requestWithURL:(NSURL *)url {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	return request;
}

- (void)enqueueHTTPRequestOperation:(AFHTTPRequestOperation *)operation {
	operation.successCallbackQueue = _callbackQueue;
	operation.failureCallbackQueue = _callbackQueue;
	[super enqueueHTTPRequestOperation:operation];
}

#pragma mark - Syncing Podcast Feed

- (void)syncPodcastFeedWithCompletion:(void (^)(BOOL success, NSError *error))completion {
    NSMutableURLRequest *request = [self requestWithURL:[self audioFeedURL]];
    [request setTimeoutInterval:10];
    
    IGRSSXMLRequestOperation *operation = [IGRSSXMLRequestOperation RSSXMLRequestOperationWithRequest:request completion:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser, NSError *error) {
        if (error && completion) {
            completion(NO, error);
        } else if ([self podcastFeedModified:[[response allHeaderFields] valueForKey:@"Last-Modified"]]) {
            [IGPodcastFeedParser PodcastFeedParserWithXMLParser:XMLParser completion:^(NSArray *feedItems, NSError *error) {
                if (error && completion) {
                        completion(NO, error);
                }
                else {
                    [IGEpisode importPodcastFeedItems:feedItems completion:nil];
                    if (completion) {
                        completion(YES, nil);
                    }
                }
            }];
        } else if (completion) {
            completion(YES, nil);
        }
    }];
    [operation start];
}

/**
 * Checks to see if the feed has been modifed since last update.
 *
 * @return YES if feed has been modified since last update, NO otherwise.
 */
- (BOOL)podcastFeedModified:(NSString *)modifiedDate {
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDate *feedLastRefreshed = [NSDate dateFromString:[userDefaults objectForKey:@"IGFeedLastRefreshed"]
                                            withFormat:IGEpisodeDateFormat];
    NSDate *feedLastModified = [NSDate dateFromString:modifiedDate
                                           withFormat:IGEpisodeDateFormat];
    
    if (!feedLastRefreshed || ([feedLastRefreshed compare:feedLastModified] == NSOrderedAscending)) {
        [userDefaults setObject:[NSDate stringFromDate:[NSDate date]]
                         forKey:@"IGFeedLastRefreshed"];
        [userDefaults synchronize];
        return YES;
    }
    
    return NO;
}

#pragma mark - Downloading Episode

- (void)downloadEpisodeWithURL:(NSURL *)downloadURL
                    targetPath:(NSURL *)targetPath
                       success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                       failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure {
    if ([self allowCellularDataDownloading] && failure)
    {
        // If data downloading is not allowed on cellular return an error
        NSError *error = [NSError errorWithDomain:IGHTTPClientNetworkErrorDomain
                                             code:IGHTTPClientNetworkErrorCellularDataDownloadingNotAllowed
                                         userInfo:nil];
        failure(nil, error);
    }
    
    [self addDownloadRequest:downloadURL
                  targetPath:targetPath];
    
    NSMutableURLRequest *request = [self requestWithURL:downloadURL];
    AFDownloadRequestOperation *operation = [[AFDownloadRequestOperation alloc] initWithRequest:request
                                                                                     targetPath:[targetPath path]
                                                                                   shouldResume:YES];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        [self removeDownloadRequest:downloadURL
                         targetPath:targetPath];
        if (success) {
            success(operation, responseObject);
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        [self removeDownloadRequest:downloadURL
                         targetPath:targetPath];
        if (failure) {
            failure(operation, error);
        }
    }];
    [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
    [self enqueueHTTPRequestOperation:operation];
}

- (BOOL)allowCellularDataDownloading {
    BOOL allowCellularDataDownloading = [[NSUserDefaults standardUserDefaults] boolForKey:IGSettingCellularDataDownloading];
    AFNetworkReachabilityStatus networkReachabilityStatus = [self networkReachabilityStatus];
    if (!allowCellularDataDownloading && networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN) {
        return YES;
    }
    
    return NO;
}

#pragma mark - Download Operations

- (NSArray *)downloadOperations
{
    return [[self operationQueue] operations];
}

- (AFHTTPRequestOperation *)requestOperationForURL:(NSURL *)url
{
    __block AFHTTPRequestOperation *requestOperation = nil;
    NSArray *downloadOperations = [self downloadOperations];
    [downloadOperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([[[obj request] URL] isEqual:url])
        {
            requestOperation = obj;
            *stop = YES;
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
