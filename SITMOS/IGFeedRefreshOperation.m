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

#import "IGFeedRefreshOperation.h"
#import "IGEpisode.h"
#import "RIButtonItem.h"
#import "UIAlertView+Blocks.h"
#import "TBXML.h"

@interface IGFeedRefreshOperation ()

@property (strong, nonatomic) NSURL *url;
@property (strong, nonatomic) NSDateFormatter *dateFormatter;
@property (strong, nonatomic) NSNumberFormatter *numberFormatter;

@end

@implementation IGFeedRefreshOperation

+ (IGFeedRefreshOperation *)refreshFeedWithURL:(NSURL *)url
{
    return [[self alloc] initWithURL:url];
}

- (id)initWithURL:(NSURL *)url
{
    self = [super init];
    
    _isFinished = NO;
    _isExecuting = NO;
    _isCancelled = NO;
    
    _url = url;
    
    _numberFormatter = [[NSNumberFormatter alloc] init];
    
    _dateFormatter = [[NSDateFormatter alloc] init];
    [_dateFormatter setDateFormat:IGDateFormat];
    
    return self;
}

- (void)main
{
    if (self.isCancelled || self.isFinished) return;
    
    KVO_SET(isExecuting, YES);
    
    [self fetchFeed];
}

- (void)start
{
    [self main];
}

- (void)cancel
{
    if (self.isCancelled) return;
    
    KVO_SET(isCancelled, YES);
    KVO_SET(isFinished, YES);
    KVO_SET(isExecuting, NO);
    
    [super cancel];
}

- (void)fetchFeed
{
    NSURLRequest *urlRequest = [NSURLRequest requestWithURL:_url
                                                cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                            timeoutInterval:10];
    
    NSHTTPURLResponse __autoreleasing *response;
    NSError __autoreleasing *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:urlRequest
                                  returningResponse:&response
                                              error:&error];
    if (error)
    {
        [self presentAlertWithError:error];
    }
    
    if ([IGEpisode MR_countOfEntities] == 0 || [self feedModified:[_dateFormatter dateFromString:[[response allHeaderFields] valueForKey:@"Last-Modified"]]])
    {
        [self parseData:data];
    }
    else
    {
        KVO_SET(isCancelled, NO);
        KVO_SET(isFinished, YES);
        KVO_SET(isExecuting, NO);
    }
}

/**
 If the last modified date from the response headers is after the
 feed last refresehed key stored in the user defaults return YES
 otherwise return NO.
 */
- (BOOL)feedModified:(NSDate *)lastModified
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSDate *feedLastRefreshed = [_dateFormatter dateFromString:[userDefaults objectForKey:@"IGFeedLastRefreshed"]];
    
    if (!feedLastRefreshed || ([feedLastRefreshed compare:lastModified] == NSOrderedAscending))
    {
        [userDefaults setObject:[_dateFormatter stringFromDate:[NSDate date]]
                         forKey:@"IGFeedLastRefreshed"];
        [userDefaults synchronize];
        return YES;
    }
    
    return NO;
}

- (void)parseData:(NSData *)data
{
    if (self.isCancelled || self.isFinished || !data) return;
    
    TBXML *tbxml = [TBXML tbxmlWithXMLData:data
                                     error:nil];
    TBXMLElement *root = tbxml.rootXMLElement;
    
    if (!root)
    {
        [self cancel];
    }
    
    TBXMLElement *channel = [TBXML childElementNamed:@"channel"
                                       parentElement:root];
    
    if (!channel)
    {
        [self cancel];
    }
    
    __block NSDate *latestEpisodePubDate;
    [TBXML iterateElementsForQuery:@"item" fromElement:channel withBlock:^(TBXMLElement *anElement) {
        TBXMLElement *pubDateElement = [TBXML childElementNamed:@"pubDate"
                                                  parentElement:anElement];
        if (pubDateElement)
        {
            latestEpisodePubDate = [_dateFormatter dateFromString:[TBXML textForElement:pubDateElement]];
        }
    }];
    
    // Iterate over the episodes in XML data, saving any new episode to the core data stack.
    [MagicalRecord saveInBackgroundWithBlock:^(NSManagedObjectContext *localContext) {
        [TBXML iterateElementsForQuery:@"item" fromElement:channel withBlock:^(TBXMLElement *anElement) {
            TBXMLElement *titleElement = [TBXML childElementNamed:@"title"
                                                    parentElement:anElement];
            NSString *title = [TBXML textForElement:titleElement];
            
            // Don't add an episode more than once.
            NSArray *anyDuplicates = [IGEpisode MR_findByAttribute:@"title" 
                                                         withValue:title];
            if ([anyDuplicates count] == 0)
            {
                IGEpisode *episode = [IGEpisode MR_createInContext:localContext];
                
                if (titleElement)
                {
                    [episode setTitle:title];
                }
                
                TBXMLElement *summaryElement = [TBXML childElementNamed:@"itunes:summary"
                                                          parentElement:anElement];
                if (summaryElement)
                {
                    [episode setSummary:[TBXML textForElement:summaryElement]];
                }
                
                NSDate *episodePubDate;
                TBXMLElement *pubDateElement = [TBXML childElementNamed:@"pubDate"
                                                          parentElement:anElement];
                if (pubDateElement)
                {
                    episodePubDate = [_dateFormatter dateFromString:[TBXML textForElement:pubDateElement]];
                    [episode setPubDate:episodePubDate];
                }
                
                TBXMLElement *enclosureElement = [TBXML childElementNamed:@"enclosure"
                                                            parentElement:anElement];
                if (enclosureElement)
                {
                    [episode setDownloadURL:[TBXML valueOfAttributeNamed:@"url" 
                                                      forElement:enclosureElement]];
                    [episode setFileSize:[_numberFormatter numberFromString:[TBXML valueOfAttributeNamed:@"length"
                                                                                              forElement:enclosureElement]]];
                    [episode setType:[TBXML valueOfAttributeNamed:@"type" 
                                                       forElement:enclosureElement]];
                }
                
                TBXMLElement *durationElement = [TBXML childElementNamed:@"itunes:duration"
                                                           parentElement:anElement];
                if (durationElement)
                {
                    [episode setDuration:[TBXML textForElement:durationElement]];
                }
                
                // Get the file type extension
                NSString *fileTypeExtension = [self getFileTypeExtension:[TBXML valueOfAttributeNamed:@"type" 
                                                                                           forElement:enclosureElement]];
                
                // File name layout example: Episode 68.mp3
                NSString *episodeFileName = [NSString stringWithFormat:@"%@%@", title, fileTypeExtension];
                [episode setFileName:episodeFileName];
                
                // Only mark the latest episode as unplayed
                [episodePubDate isEqualToDate:latestEpisodePubDate] ? [episode markAsPlayed:NO] : [episode markAsPlayed:YES];
            }
        }];

        [localContext MR_saveNestedContexts];
    } completion:^{
        KVO_SET(isCancelled, NO);
        KVO_SET(isFinished, YES);
        KVO_SET(isExecuting, NO);
    }];
}

- (NSString *)getFileTypeExtension:(NSString *)fileType
{
    if ([fileType isEqualToString:@"audio/mpeg"])
    {
        return @".mp3";
    }
    else if ([fileType isEqualToString:@"video/mp4"])
    {
        return @".mp4";
    }
    
    return nil;
}

#pragma mark - Present Error

- (void)presentAlertWithError:(NSError *)error
{
    dispatch_async(dispatch_get_main_queue(), ^{
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Cancel", "text label for cancel")];
        cancelItem.action = ^{
            [self cancel];
        };
        RIButtonItem *retryItem = [RIButtonItem itemWithLabel:NSLocalizedString(@"Retry", "text label for retry")];
        retryItem.action = ^{
            [self fetchFeed];
        };
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[error localizedDescription]
                                                            message:[error localizedFailureReason]
                                                   cancelButtonItem:cancelItem
                                                   otherButtonItems:retryItem, nil];
        [alertView show];
    });
}

@end