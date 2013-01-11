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

#import "IGEpisodeParserTests.h"
#import "IGEpisodeParser.h"

static NSString *audioPodcastTestFeed = @"<?xml version=\"1.0\" encoding=\"UTF-8\"?>"
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

@interface IGEpisodeParserTests ()

@property (nonatomic, strong) NSArray *episodes;
@property (nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic, strong) NSError *error;

@end

@implementation IGEpisodeParserTests

- (void)setUp
{
    _xmlParser = [[NSXMLParser alloc] initWithData:[audioPodcastTestFeed dataUsingEncoding:NSUTF8StringEncoding]];
    
   [IGEpisodeParser EpisodeParserWithXMLParser:_xmlParser success:^(NSArray *episodes) {
        _episodes = episodes;
    } failure:^(NSError *error) {
        _error = error;
    }];
}

- (void)tearDown
{
    _episodes = nil;
    _xmlParser = nil;
}

- (void)testThatEpisodesCountIsGreaterThanOne
{
    STAssertTrue([_episodes count] > 0, @"Episodes array count should be greater than 1");
}

- (void)testThatEpisodeCreatedFromXMLHasPropertiesPresentedInXML
{
    NSDictionary *episode = [_episodes objectAtIndex:0];
    STAssertEqualObjects([episode valueForKey:@"title"], @"Episode 1", @"The title should match the title presented in the XML");
    STAssertEqualObjects([episode valueForKey:@"pubDate"], @"Tue, 10 Aug 2010 00:00:00 MST", @"The pub date should match the pubDate presented in the XML");
    STAssertEqualObjects([episode valueForKey:@"summary"], @"Achievements, Arizona Immigration Laws, and Annoying Social Networking Apps", @"The summary should match the summary presented by the XML");
    STAssertEqualObjects([episode valueForKey:@"url"], @"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3", @"The url should match the url presented by the XML");
    STAssertEqualObjects([episode valueForKey:@"length"], @"28900000", @"The length should match the length presented by the XML");
    STAssertEqualObjects([episode valueForKey:@"type"], @"audio/mpeg", @"The type should match the type presented by the XML");
    STAssertEqualObjects([episode valueForKey:@"duration"], @"31:15", @"The duration should match the duration presented by the XML");
}

@end
