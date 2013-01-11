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

#import "IGEpisodeBuilder.h"
#import "IGEpisode.h"

NSString * const IGEpisodeBuilderError = @"IGEpisodeBuilderError";
NSString * const IGEpisodeBuilderDateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";

@interface IGEpisodeBuilder ()

@property (nonatomic, strong) NSArray *episodes;
@property (nonatomic, copy) void (^success)(void);

@end

@implementation IGEpisodeBuilder

+ (IGEpisodeBuilder *)EpisodeBuilderWithEpisodes:(NSArray *)episodes success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    if (!episodes)
    {
        NSError *error = [NSError errorWithDomain:IGEpisodeBuilderError
                                             code:IGEpisodeBuilderErrorMissingData
                                         userInfo:nil];
        failure(error);
        return nil;
    }
    
    IGEpisodeBuilder *episodeBuilder = [[IGEpisodeBuilder alloc] initWithEpisodes:episodes success:success failure:failure];
    [episodeBuilder start];
    
    return episodeBuilder;
}

- (id)initWithEpisodes:(NSArray *)episodes success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _episodes = episodes;
    _success = success;
    
    return self;
}

- (void)start
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:IGEpisodeBuilderDateFormat];
    NSDate *latestEpisodePubDate = [dateFormatter dateFromString:[[_episodes lastObject] valueForKey:@"pubDate"]];
    
    [MagicalRecord saveInBackgroundWithBlock:^(NSManagedObjectContext *localContext) {
        [_episodes enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj objectForKey:@"title"];
            NSArray *anyDuplicates = [IGEpisode MR_findByAttribute:@"title"
                                                         withValue:title];
            if ([anyDuplicates count] == 0)
            {
                IGEpisode *episode = [IGEpisode MR_createInContext:localContext];
                [episode setTitle:title];
                [episode setSummary:[obj objectForKey:@"summary"]];
                [episode setDownloadURL:[obj objectForKey:@"url"]];
                [episode setType:[obj objectForKey:@"type"]];
                [episode setDuration:[obj objectForKey:@"duration"]];
                
                NSDate *episodePubDate = [dateFormatter dateFromString:[obj objectForKey:@"pubDate"]];
                [episode setPubDate:episodePubDate];
                
                NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
                [episode setFileSize:[numberFormatter numberFromString:[obj objectForKey:@"length"]]];
                numberFormatter = nil;
                
                NSString *episodeFileName = [NSString stringWithFormat:@"%@.mp3", title];
                [episode setFileName:episodeFileName];
                
                // Only mark the latest episode as unplayed
                if ([episodePubDate isEqualToDate:latestEpisodePubDate])
                {
                    [episode markAsPlayed:NO];
                }
            }
        }];
//        [localContext MR_saveNestedContexts];
    } completion:^{
        _success();
    }];
}

@end
