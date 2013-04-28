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

#import "IGPodcastFeedParser.h"

@interface IGPodcastFeedParser () <NSXMLParserDelegate>

@property (nonatomic, strong) NSXMLParser *XMLParser;
@property (nonatomic, strong) NSNumberFormatter *numberFormatter;
@property (nonatomic, strong) NSMutableArray *feedItems;
@property (nonatomic, strong) NSMutableDictionary *currentFeedItem;
@property (nonatomic, strong) NSMutableString *tmpString;
@property (nonatomic, copy) void (^completion)(NSArray *feedItems, NSError *error);

@end

@implementation IGPodcastFeedParser

+ (IGPodcastFeedParser *)PodcastFeedParserWithXMLParser:(NSXMLParser *)XMLParser
                                             completion:(void (^) (NSArray *feedItems, NSError *error))completion {
    IGPodcastFeedParser *feedParser = [[IGPodcastFeedParser alloc] initWithXMLParser:XMLParser
                                                                          completion:completion];
    [feedParser start];
    
    return feedParser;
}

- (id)initWithXMLParser:(NSXMLParser *)XMLParser
             completion:(void (^) (NSArray *feedItems, NSError *error))completion {
    if (!(self = [super init])) {
        return nil;
    }
    
    _XMLParser = XMLParser;
    [_XMLParser setDelegate:self];
    _numberFormatter = [[NSNumberFormatter alloc] init];
    _feedItems = [[NSMutableArray alloc] init];
    _completion = completion;
    
    return self;
}

- (void)start {
    BOOL parseSuccess = [_XMLParser parse];
    if (!parseSuccess) {
        if (_completion) {
            _completion(nil, [_XMLParser parserError]);
        }
    }
}

#pragma mark - NSXMLParserDelegate

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName attributes:(NSDictionary *)attributeDict {
    _tmpString = [[NSMutableString alloc] init];
    
    if ([elementName isEqualToString:@"item"]) {
        _currentFeedItem = [[NSMutableDictionary alloc] init];
    }
    
    if ([elementName isEqualToString:@"enclosure"]) {
        [_currentFeedItem setObject:[attributeDict valueForKey:@"url"] forKey:@"downloadURL"];
        
        NSNumber *fileSize = [_numberFormatter numberFromString:[attributeDict valueForKey:@"length"]];
        [_currentFeedItem setObject:fileSize forKey:@"fileSize"];
         
        [_currentFeedItem setObject:[attributeDict valueForKey:@"type"] forKey:@"mediaType"];
    }
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if ([elementName isEqualToString:@"item"]) {
        [_feedItems addObject:_currentFeedItem];
        _currentFeedItem = nil;
    }
    
    if (_currentFeedItem && _tmpString) {
        if ([elementName isEqualToString:@"title"]) {
            [_currentFeedItem setObject:_tmpString forKey:@"title"];
        }
        
        if ([elementName isEqualToString:@"pubDate"]) {
            [_currentFeedItem setObject:_tmpString forKey:@"pubDate"];
        }
        
        if ([elementName isEqualToString:@"itunes:summary"]) {
            [_currentFeedItem setObject:_tmpString forKey:@"summary"];
        }
        
        if ([elementName isEqualToString:@"itunes:duration"]) {
            [_currentFeedItem setObject:_tmpString forKey:@"duration"];
        }
    
        _tmpString = nil;
    }
    
    if ([elementName isEqualToString:@"rss"]) {
        if (_completion) {
            _completion(_feedItems, nil);
        }
    }
}

- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    [_tmpString appendString:string];
}

@end
