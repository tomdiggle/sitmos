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

#import "IGEpisodeParser.h"
#import "IGEpisode.h"

NSString * const IGEpisodeParserDateFormat = @"EEE, dd MMM yyyy HH:mm:ss zzz";

@interface IGEpisodeParser () <NSXMLParserDelegate>

@property (nonatomic, strong) NSXMLParser *XMLParser;
@property (nonatomic, copy) void (^success)(void);
@property (nonatomic, copy) void (^failure)(NSError *error);
@property (nonatomic, strong) NSMutableDictionary *currentEpisode;
@property (nonatomic, strong) NSMutableArray *episodes;
@property (nonatomic, strong) NSMutableString *tmpString;

@end

@implementation IGEpisodeParser

+ (IGEpisodeParser *)EpisodeParserWithXMLParser:(NSXMLParser *)XMLParser success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    IGEpisodeParser *episodeParser = [[IGEpisodeParser alloc] initWithXMLParser:XMLParser success:success failure:failure];
    [episodeParser start];
    
    return episodeParser;
}

- (id)initWithXMLParser:(NSXMLParser *)XMLParser success:(void (^)(void))success failure:(void (^)(NSError *error))failure
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _success = success;
    _failure = failure;
    _episodes = [[NSMutableArray alloc] init];
    _XMLParser = XMLParser;
    [_XMLParser setDelegate:self];
    
    return self;
}

- (void)start
{
    BOOL parseSuccess = [_XMLParser parse];
    if (!parseSuccess)
    {
        _failure([_XMLParser parserError]);
    }
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict
{
    _tmpString = [[NSMutableString alloc] init];
    
    if ([elementName isEqualToString:@"item"])
    {
        _currentEpisode = [[NSMutableDictionary alloc] init];
    }
    
    if ([elementName isEqualToString:@"enclosure"])
    {
        [_currentEpisode setObject:[attributeDict valueForKey:@"url"] forKey:@"url"];
        [_currentEpisode setObject:[attributeDict valueForKey:@"length"] forKey:@"length"];
        [_currentEpisode setObject:[attributeDict valueForKey:@"type"] forKey:@"type"];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
    if ([elementName isEqualToString:@"item"])
    {
        [_episodes addObject:_currentEpisode];
        _currentEpisode = nil;
    }
    
    if (_currentEpisode && _tmpString)
    {
        if ([elementName isEqualToString:@"title"])
        {
            [_currentEpisode setObject:_tmpString forKey:@"title"];
        }
        
        if ([elementName isEqualToString:@"pubDate"])
        {
            [_currentEpisode setObject:_tmpString forKey:@"pubDate"];
        }
        
        if ([elementName isEqualToString:@"itunes:summary"])
        {
            [_currentEpisode setObject:_tmpString forKey:@"summary"];
        }
        
        if ([elementName isEqualToString:@"itunes:duration"])
        {
            [_currentEpisode setObject:_tmpString forKey:@"duration"];
        }
    
        _tmpString = nil;
    }
    
    if ([elementName isEqualToString:@"rss"])
    {
        [self buildEpisodes];
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
    [_tmpString appendString:string];
}

#pragma mark - Build Episodes

/*
 Builds the episodes from parsed xml data and saves them into the Core Data stack.
 */
- (void)buildEpisodes
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:IGEpisodeParserDateFormat];
    NSDate *latestEpisodePubDate = [dateFormatter dateFromString:[[_episodes lastObject] valueForKey:@"pubDate"]];
    
    [MagicalRecord saveWithBlock:^(NSManagedObjectContext *localContext) {
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
            else
            {
                IGEpisode *episode = [[anyDuplicates objectAtIndex:0] MR_inContext:localContext];
                NSDate *episodePubDate = [dateFormatter dateFromString:[obj objectForKey:@"pubDate"]];
                if (![episodePubDate isEqualToDate:[episode pubDate]])
                {
                    [episode setPubDate:episodePubDate];
                }
            }
        }];
    } completion:^(BOOL success, NSError *error) {
        _success();
    }];
}

@end
