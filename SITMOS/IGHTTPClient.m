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
#import "IGEpisodeParser.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFDownloadRequestOperation.h"

NSString * const IGHTTPClientNetworkErrorDomain = @"IGHTTPClientNetworkErrorDomain";

@interface IGHTTPClient ()

@property (nonatomic, strong) dispatch_queue_t callbackQueue;

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

#pragma mark - Initializers

- (id)init
{
    NSURL *baseURL = [NSURL URLWithString:@"http://www.dereksweet.com/"];
    
    if ((self = [super initWithBaseURL:baseURL]))
    {
        [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:YES];
        _callbackQueue = dispatch_queue_create("com.IdleGeniusSoftware.SITMOS.network-callback-queue", NULL);
    }
    
    return self;
}

#pragma mark - Feed URLs

- (NSURL *)audioFeedURL
{
#ifdef DEVELOPMENT
    return [NSURL URLWithString:@"http://www.tomdiggle.com/sitmos-test-feed/sitmos-audio-feed.xml"];
#else
    return [NSURL URLWithString:@"http://www.dereksweet.com/sitmos/sitmos.xml"];
#endif
}

#pragma mark - AFHTTPClient

- (NSMutableURLRequest *)requestWithURL:(NSURL *)url
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
	return request;
}

- (void)enqueueHTTPRequestOperation:(AFHTTPRequestOperation *)operation
{
	operation.successCallbackQueue = _callbackQueue;
	operation.failureCallbackQueue = _callbackQueue;
	[super enqueueHTTPRequestOperation:operation];
}

#pragma mark - Syncing Podcast Feed

- (void)syncPodcastFeedWithSuccess:(void (^)(void))success
                           failure:(void (^)(NSError *error))failure
{
    NSMutableURLRequest *request = [self requestWithURL:[self audioFeedURL]];
    
    IGRSSXMLRequestOperation *operation = [IGRSSXMLRequestOperation RSSXMLRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:IGEpisodeParserDateFormat];
        if ([self podcastFeedModified:[dateFormatter dateFromString:[[response allHeaderFields] valueForKey:@"Last-Modified"]]])
        {
            [IGEpisodeParser EpisodeParserWithXMLParser:XMLParser success:^{
                success();
            } failure:^(NSError *error) {
                failure(error);
            }];
        }
        else
        {
            success();
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSXMLParser *XMLParser) {
        failure(error);
    }];
    [operation start];
}

/**
 * Checks to see if the feed has been modifed since last update.
 *
 * @return YES if feed has been modified since last update, NO otherwise.
 */
- (BOOL)podcastFeedModified:(NSDate *)lastModifiedDate
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:IGEpisodeParserDateFormat];
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDate *feedLastRefreshed = [dateFormatter dateFromString:[userDefaults objectForKey:@"IGFeedLastRefreshed"]];
    
    if (!feedLastRefreshed || ([feedLastRefreshed compare:lastModifiedDate] == NSOrderedAscending))
    {
        [userDefaults setObject:[dateFormatter stringFromDate:[NSDate date]]
                         forKey:@"IGFeedLastRefreshed"];
        [userDefaults synchronize];
        return YES;
    }
    
    return NO;
}

#pragma mark - Downloading Episode

- (void)downloadEpisodeWithURL:(NSURL *)downloadURL
                    targetPath:(NSString *)targetPath
                       success:(void (^)(AFHTTPRequestOperation *operation, id responseObject))success
                       failure:(void (^)(AFHTTPRequestOperation *operation, NSError *error))failure
{
    BOOL allowCellularDataDownloading = [[NSUserDefaults standardUserDefaults] boolForKey:IGSettingCellularDataDownloading];
    AFNetworkReachabilityStatus networkReachabilityStatus = [self networkReachabilityStatus];
    if (!allowCellularDataDownloading && networkReachabilityStatus == AFNetworkReachabilityStatusReachableViaWWAN)
    {
        // If data downloading is not allowed on cellular return an error
        NSError *error = [NSError errorWithDomain:IGHTTPClientNetworkErrorDomain
                                             code:IGHTTPClientNetworkErrorCellularDataDownloadingNotAllowed
                                         userInfo:nil];
        failure(nil, error);
    }
    
    NSMutableURLRequest *request = [self requestWithURL:downloadURL];
    AFDownloadRequestOperation *operation = [[AFDownloadRequestOperation alloc] initWithRequest:request
                                                                                     targetPath:targetPath
                                                                                   shouldResume:YES];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        success(operation, responseObject);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        failure(operation, error);
    }];
    [operation setShouldExecuteAsBackgroundTaskWithExpirationHandler:nil];
    [self enqueueHTTPRequestOperation:operation];
}

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

@end
