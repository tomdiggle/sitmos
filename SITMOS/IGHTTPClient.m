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

@implementation IGHTTPClient

+ (IGHTTPClient *)sharedClient
{
    static IGHTTPClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[self alloc] init];
    });
    return sharedClient;
}

#pragma mark - Sync Podcast Feed

- (void)syncPodcastFeedWithSuccess:(void(^)(void))success failure:(void (^)(NSError *error))failure
{
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:IGSITMOSFeedURL]];
    [request setCachePolicy:NSURLRequestReloadIgnoringCacheData];
    
    IGRSSXMLRequestOperation *operation = [IGRSSXMLRequestOperation RSSXMLRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:IGEpisodeParserDateFormat];
        if ([self podcastfeedModified:[dateFormatter dateFromString:[[response allHeaderFields] valueForKey:@"Last-Modified"]]])
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
 If the last modified date from the response headers is after the feed last refresehed key stored in the user defaults return YES otherwise return NO.
 */
- (BOOL)podcastfeedModified:(NSDate *)lastModifiedDate
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

@end
