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

#import "IGEpisodeDownloadOperation.h"
#import "IGEpisode.h"
#import "Reachability.h"
#import "RIButtonItem.h"
#import "UIAlertView+Blocks.h"

@interface IGEpisodeDownloadOperation ()

@property (strong, nonatomic) NSURLConnection *connection;
@property (strong, nonatomic) NSFileHandle *downloadingFileHandle;
@property (strong, nonatomic) NSTimer *downloadProgressTimer;
@property (assign, nonatomic) UIBackgroundTaskIdentifier backgroundTaskID;

@end

@implementation IGEpisodeDownloadOperation

#pragma mark - Initializers

+ (id)operationWithEpisode:(IGEpisode *)episode
{
    return [[self alloc] initWithEpisode:episode];
}

- (id)initWithEpisode:(IGEpisode *)episode
{
    self = [super init];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:kReachabilityChangedNotification
                                               object:nil];
    
    _episode = episode;
    
    _isFinished = NO;
    _isExecuting = NO;
    _isCancelled = NO;
    
    return self;
}

- (void)main
{
    if (self.isCancelled || self.isFinished) return;
    
    KVO_SET(isExecuting, YES);
    
    [self startBackgroundTask];
    
    @autoreleasepool
    {
        // Check if episode can be downloaded over cellular data
        NSURL *url = [NSURL URLWithString:[_episode downloadURL]];
        NSString *hostname = [NSString stringWithFormat:@"%@", [url host]];
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        Reachability *reach = [Reachability reachabilityWithHostname:hostname];
        reach.reachableOnWWAN = [userDefaults boolForKey:IGSettingCellularDataDownloading];
        [reach startNotifier];
        
        if (![NSThread isMainThread]) 
        {
            // Keep the thread alive while connection is executing
            // Without this NSURLConnection delegate is not called
            NSRunLoop *theRL = [NSRunLoop currentRunLoop];
            while ([self isExecuting] && [theRL runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]])
            {
                // Nothing to see here...
            }	
        }
    }
}

- (void)start
{
    [self main];
}

- (void)cancel
{
    @synchronized(self)
    {
        if (self.isCancelled) return;
        
        KVO_SET(isCancelled, YES);
        KVO_SET(isFinished, YES);
        KVO_SET(isExecuting, NO);
        
        [_connection cancel];
        _connection = nil;
        [_downloadingFileHandle closeFile];
        _downloadingFileHandle = nil;
        
        [self endBackgroundTask];
        
        if ([_downloadProgressTimer isValid]) [_downloadProgressTimer invalidate];
        
        [self updateDownloadProgress];
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:kReachabilityChangedNotification
                                                      object:nil];
        
        [super cancel];
    }
}

#pragma mark - Start Download

- (void)startDownload
{
    NSURL *episodeURL = [NSURL URLWithString:[_episode downloadURL]];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:episodeURL
                                                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                                                          timeoutInterval:30];
    
    if (![NSURLConnection canHandleRequest:urlRequest])
    {
        [self cancel];
    }

    // Resume downloading episode
    if ([_episode downloadedFileSize] > 0)
    {
        [urlRequest addValue:[NSString stringWithFormat:@"bytes=%u-", [_episode downloadedFileSize]]
          forHTTPHeaderField:@"Range"];
    }
    else
    {
        // Create the new episode file for the episode that is being downloaded
        if (![[NSFileManager defaultManager] createFileAtPath:[_episode filePath] contents:nil attributes:nil])
        {
            // Generate an error describing the failure.
            NSString *localizedDescription = NSLocalizedString(@"ErrorCreatingFileTitle", @"text label for error creating file title");
            NSString *localizedFailureReason = NSLocalizedString(@"ErrorCreatingFileDesc", @"text label for error creating file desc");
            NSDictionary *errorDict = @{NSLocalizedDescriptionKey: localizedDescription,
            NSLocalizedFailureReasonErrorKey: localizedFailureReason};
            NSError *error = [NSError errorWithDomain:IGSITMOSErrorDomain
                                                 code:0
                                             userInfo:errorDict];
            [self presentAlertWithError:error];
        }
    }
    
    _connection = [[NSURLConnection alloc] initWithRequest:urlRequest
                                                  delegate:self
                                          startImmediately:YES];
}

#pragma mark - Background Task

- (void)startBackgroundTask
{
    _backgroundTaskID = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_backgroundTaskID != UIBackgroundTaskInvalid)
            {
                [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskID];
                _backgroundTaskID = UIBackgroundTaskInvalid;
                [self cancel];
            }
        });
    }];
}

- (void)endBackgroundTask
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_backgroundTaskID != UIBackgroundTaskInvalid)
        {
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundTaskID];
            _backgroundTaskID = UIBackgroundTaskInvalid;
        }
    });
}

#pragma mark - Download Progress Timer

/**
 Starts the download progress timer.
 */
- (void)startDownloadProgressTimer
{
    if (_downloadProgressTimer) return;
    
    _downloadProgressTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
                                                              target:self
                                                            selector:@selector(updateDownloadProgress)
                                                            userInfo:nil
                                                             repeats:YES];
}

- (void)updateDownloadProgress
{
    NSDictionary *userInfo = @{
                                @"contentLength": [_episode fileSize],
                                @"bytesDownloaded": @([_downloadingFileHandle seekToEndOfFile]),
                                @"episodeTitle": [_episode title],
                                @"isFinished": @(_isFinished),
                                @"isCancelled": @(_isCancelled)
                              };
    
    NSNotification *notification = [NSNotification notificationWithName:IGDownloadProgressNotification
                                                                 object:nil
                                                               userInfo:userInfo];
    dispatch_async(dispatch_get_main_queue(), ^{    
        [[NSNotificationCenter defaultCenter] postNotification:notification];
    });
}

#pragma mark - NSURLConnectionDelegate

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response 
{
    NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
    
    // Display the network activity indicator
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        
    NSFileHandle *fh = [NSFileHandle fileHandleForWritingAtPath:[_episode filePath]];
    _downloadingFileHandle = fh;
    
    // Thanks to Mike Nachbaur for the following code - http://nachbaur.com/blog/resuming-large-downloads-with-nsurlconnection
    // Checks to see if the server understands the Range HTTTP header
    switch (httpResponse.statusCode)
    {
        case 206:
        {
            NSString *range = [httpResponse.allHeaderFields valueForKey:@"Content-Range"];
            NSError *error = nil;
            NSRegularExpression *regex = nil;
            // Check to see if the server returned a valid byte-range
            regex = [NSRegularExpression regularExpressionWithPattern:@"bytes (\\d+)-\\d+/\\d+"
                                                              options:NSRegularExpressionCaseInsensitive
                                                                error:&error];
            if (error) 
            {
                [fh truncateFileAtOffset:0];
                break;
            }
            
            // If the regex didn't match the number of bytes, start the download from the beginning
            NSTextCheckingResult *match = [regex firstMatchInString:range
                                                            options:NSMatchingAnchored
                                                              range:NSMakeRange(0, range.length)];
            if (match.numberOfRanges < 2) 
            {
                [fh truncateFileAtOffset:0];
                break;
            }
            
            // Extract the byte offset the server reported to us, and truncate our
            // file if it is starting us at "0".  Otherwise, seek our file to the
            // appropriate offset.
            NSString *byteStr = [range substringWithRange:[match rangeAtIndex:1]];
            NSInteger bytes = [byteStr integerValue];
            if (bytes <= 0)
            {
                [fh truncateFileAtOffset:0];
                break;
            } 
            else 
            {
                [fh seekToFileOffset:bytes];
            }
            break;
        }
        default:
            [fh truncateFileAtOffset:0];
            break;
    }
    
    [self startDownloadProgressTimer];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge 
{
    [self cancel];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data 
{
    [_downloadingFileHandle writeData:data];
    [_downloadingFileHandle synchronizeFile];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error 
{
    [self presentAlertWithError:error];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    KVO_SET(isCancelled, NO);
    KVO_SET(isFinished, YES);
    KVO_SET(isExecuting, NO);
    
    _connection = nil;
    [_downloadingFileHandle closeFile];
    _downloadingFileHandle = nil;
    
    [self endBackgroundTask];
    
    if ([_downloadProgressTimer isValid]) [_downloadProgressTimer invalidate];
    
    [self updateDownloadProgress];
    
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kReachabilityChangedNotification
                                                  object:nil];
}

#pragma mark - Alerts

- (void)presentAlertWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"OK", "text label for OK")];
        cancelItem.action = ^{
            [self cancel];
        };
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription] 
                                                            message:[error localizedFailureReason] 
                                                   cancelButtonItem:cancelItem 
                                                   otherButtonItems:nil];
        [alertView show];
    });
}

- (void)presentAlertDownloadingWithCellularData
{
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", "text label for cancel")];
    cancelItem.action = ^{
        [self cancel];
    };
    RIButtonItem *downloadItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Download", @"text label for download")];
    downloadItem.action = ^{
        [self startDownload];
    };
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"DownloadingWithCellularDataTitle", @"text label for downloading with cellular data title")
                                                        message:NSLocalizedString(@"DownloadingWithCellularDataMessage", @"text label for downloading with cellular data message")
                                               cancelButtonItem:cancelItem
                                               otherButtonItems:downloadItem, nil];
    [alertView show];
}

#pragma mark - Reachability

- (void)reachabilityChanged:(NSNotification*)note
{
    Reachability *reach = [note object];
    
    if([reach isReachable])
    {
        [self startDownload];
    }
    else
    {
        if (_connection)
        {
            // Cancel any current connections (incase connection changed from WiFi to cellular)
            [_connection cancel];
        }
        
        [self presentAlertDownloadingWithCellularData];
    }
}

@end
