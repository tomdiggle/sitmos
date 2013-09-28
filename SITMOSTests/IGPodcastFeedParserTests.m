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

#import <SenTestingKit/SenTestingKit.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

static NSString *errorXMLString = @"Error XML";

static NSString *feedXMLString = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<rss xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\" version=\"2.0\">"
@"<channel>"
@"<title>Stuck in the Middle of Somewhere</title>"
@"<link>http://www.sitmos.net/</link>"
@"<language>en-us</language>"
@"<copyright>(C) 2012</copyright>"
@"<itunes:subtitle>TV Actor Joel Gardiner and Comedian Derek Sweet discuss whatever is on their minds.</itunes:subtitle>"
@"<itunes:author>Joel Gardiner and Derek Sweet</itunes:author>"
@"<itunes:summary>TV Actor Joel Gardiner and Comedian Derek Sweet discuss whatever is on their minds. While video games are often the focus of conversation, topics of discussion can be almost anything. One thing is for sure, it's always hilarious and entertaining.</itunes:summary>"
@"<description>TV Actor Joel Gardiner and Comedian Derek Sweet discuss whatever is on their minds. While video games are often the focus of conversation, topics of discussion can be almost anything. One thing is for sure, it's always hilarious and entertaining.</description>"
@"<itunes:owner>"
@"<itunes:name>Joel Gardiner and Derek Sweet</itunes:name>"
@"<itunes:email>joel@sitmos.net</itunes:email>"
@"</itunes:owner>"
@"<itunes:image href=\"http://www.dereksweet.com/sitmos/logo.png\" />"
@"<itunes:category text=\"Comedy\" />"
@"<itunes:explicit>Yes</itunes:explicit>"
@"<itunes:image href=\"http://www.dereksweet.com/sitmos/logo.png\" />"
@"<item>"
@"<title>Episode 1</title>"
@"<itunes:author>Joel Gardiner and Derek Sweet</itunes:author>"
@"<itunes:summary>Achievements, Arizona Immigration Laws, and Annoying Social Networking Apps</itunes:summary>"
@"<itunes:image href=\"http://www.sitmos.net/episode_pics/1.jpg\" />"
@"<pubDate>Tue, 10 Aug 2010 00:00:00 MST</pubDate>"
@"<enclosure url=\"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3\" length=\"28900000\" type = \"audio/mpeg\" />"
@"<guid>https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3</guid>"
@"<itunes:duration>31:15</itunes:duration>"
@"<itunes:keywords>achievements, immigration, social networking</itunes:keywords>"
@"</item>"
@"</channel>"
@"</rss>";

@interface IGPodcastFeedParserTests : SenTestCase

@property (nonatomic, strong) NSXMLParser *feedXMLParser;
@property (nonatomic, strong) NSXMLParser *errorXMLParser;

@end

@implementation IGPodcastFeedParserTests
{
    
}

- (void)setUp {
    self.feedXMLParser = [[NSXMLParser alloc] initWithData:[feedXMLString dataUsingEncoding:NSUTF8StringEncoding]];
    self.errorXMLParser = [[NSXMLParser alloc] initWithData:[errorXMLString dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)tearDown {
    self.feedXMLParser = nil;
    self.errorXMLParser = nil;
}

#pragma mark - Audio Podcast Feed Tests

- (void)testEpisodeFeedParserReturnsTitlePresentedInFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.feedXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"title"], equalTo(@"Episode 1"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsPubDatePresentedInFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.feedXMLParser completion:^(NSArray *episodes, NSError *error) {
       
        assertThat([[episodes objectAtIndex:0] valueForKey:@"pubDate"], equalTo(@"Tue, 10 Aug 2010 08:00:00 BST"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsSummaryPresentedInFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.feedXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"summary"], equalTo(@"Achievements, Arizona Immigration Laws, and Annoying Social Networking Apps"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
 
}

- (void)testEpisodeFeedParserReturnsDownloadURLPresentedInFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.feedXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"downloadURL"], equalTo(@"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsFileSizePresentedInFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.feedXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"fileSize"], equalTo(@(28900000)));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsMediaTypePresentedInFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.feedXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"mediaType"], equalTo(@"audio/mpeg"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsDurationPresentedInFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.feedXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"duration"], equalTo(@"31:15"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

#pragma mark - Error Tests

- (void)testEpisodeFeedParserReturnsErrorWhenErrorOccurs {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.errorXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat(error, notNilValue());
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsNilEpisodeArrayWhenErrorOccurs {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:self.errorXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat(episodes, nilValue());
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

@end
