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

static NSString *errorXMLFeed = @"Error XML";

static NSString *audioPodcastFeed = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
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

static NSString *videoPodcastFeed = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
@"<rss xmlns:itunes=\"http://www.itunes.com/dtds/podcast-1.0.dtd\" version=\"2.0\">"
@"<channel>"
@"<title>Stuck in the Middle of Somewhere</title>"
@"<itunes:summary>TV Actor Joel Gardiner and Comedian Derek Sweet discuss whatever is on their minds. While video games are often the focus of conversation, topics of discussion can be almost anything. One thing is for sure, it's always hilarious and entertaining.</itunes:summary>"
@"<link>http://www.sitmos.net</link>"
@"<item>"
@"<title>Episode 15</title>"
@"<itunes:author>Joel Gardiner and Derek Sweet</itunes:author>"
@"<itunes:summary>Stuck in the Middle of Somewhere Video Special - In This Special Video Edition of the Podcast, Derek and I Go Back In Time and Play a Bunch of His Old Sega Dreamcast Games To See If They Still Hold Up Today, Or If We Just Wasted 4 Hours of Our Life.</itunes:summary>"
@"<pubDate>Sat, 25 Dec 2010 00:00:00 MST</pubDate>"
@"<enclosure url=\"http://vimeo.com/18185007\" length=\"0\" type=\"video/web\" />"
@"<guid>http://http://vimeo.com/18185007</guid>"
@"<itunes:duration>51:50</itunes:duration>"
@"</item>"
@"</channel>"
@"</rss>";

@interface IGPodcastFeedParserTests : SenTestCase

@property (nonatomic, strong) NSXMLParser *audioXMLParser;
@property (nonatomic, strong) NSXMLParser *videoXMLParser;
@property (nonatomic, strong) NSXMLParser *errorXMLParser;

@end

@implementation IGPodcastFeedParserTests
{
    
}

- (void)setUp {
    _audioXMLParser = [[NSXMLParser alloc] initWithData:[audioPodcastFeed dataUsingEncoding:NSUTF8StringEncoding]];
    _videoXMLParser = [[NSXMLParser alloc] initWithData:[videoPodcastFeed dataUsingEncoding:NSUTF8StringEncoding]];
    _errorXMLParser = [[NSXMLParser alloc] initWithData:[errorXMLFeed dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)tearDown {
    _audioXMLParser = nil;
    _videoXMLParser = nil;
    _errorXMLParser = nil;
}

#pragma mark - Audio Podcast Feed Tests

- (void)testEpisodeFeedParserReturnsTitlePresentedInAudioFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_audioXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"title"], equalTo(@"Episode 1"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsPubDatePresentedInAudioFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_audioXMLParser completion:^(NSArray *episodes, NSError *error) {
       
        assertThat([[episodes objectAtIndex:0] valueForKey:@"pubDate"], equalTo(@"Tue, 10 Aug 2010 08:00:00 BST"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsSummaryPresentedInAudioFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_audioXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"summary"], equalTo(@"Achievements, Arizona Immigration Laws, and Annoying Social Networking Apps"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
 
}

- (void)testEpisodeFeedParserReturnsDownloadURLPresentedInAudioFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_audioXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"downloadURL"], equalTo(@"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsFileSizePresentedInAudioFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_audioXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"fileSize"], equalTo(@(28900000)));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsMediaTypePresentedInAudioFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_audioXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"mediaType"], equalTo(@"audio/mpeg"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsDurationPresentedInAudioFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_audioXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"duration"], equalTo(@"31:15"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

#pragma mark - Video Podcast Feed Tests

- (void)testEpisodeFeedParserReturnsTitlePresentedInVideoFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_videoXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"title"], equalTo(@"Episode 15"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsPubDatePresentedInVideoFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_videoXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"pubDate"], equalTo(@"Sat, 25 Dec 2010 07:00:00 GMT"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsSummaryPresentedInVideoFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_videoXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"summary"], equalTo(@"Stuck in the Middle of Somewhere Video Special - In This Special Video Edition of the Podcast, Derek and I Go Back In Time and Play a Bunch of His Old Sega Dreamcast Games To See If They Still Hold Up Today, Or If We Just Wasted 4 Hours of Our Life."));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsDownloadURLPresentedInVideoFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_videoXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"downloadURL"], equalTo(@"http://vimeo.com/18185007"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsFileSizePresentedInVideoFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_videoXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"fileSize"], equalTo(@(0)));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsMediaTypePresentedInVideoFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_videoXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"mediaType"], equalTo(@"video/web"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

- (void)testEpisodeFeedParserReturnsDurationPresentedInVideoFeedXML {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_videoXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat([[episodes objectAtIndex:0] valueForKey:@"duration"], equalTo(@"51:50"));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
    
}

#pragma mark - Error Tests

- (void)testEpisodeFeedParserReturnsErrorWhenErrorOccurs {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_errorXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat(error, notNilValue());
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)testEpisodeFeedParserReturnsNilEpisodeArrayWhenErrorOccurs {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGPodcastFeedParser PodcastFeedParserWithXMLParser:_errorXMLParser completion:^(NSArray *episodes, NSError *error) {
        
        assertThat(episodes, nilValue());
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}


@end
