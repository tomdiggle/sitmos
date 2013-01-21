//
//  IGEpisodeParserTests.m
//  SITMOS
//
//  Created by Tom Diggle on 21/01/2013.
//
//

#import <GHUnitIOS/GHUnit.h>

#import "IGEpisodeParser.h"
#import "IGEpisode.h"

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

@interface IGEpisodeParserTests : GHAsyncTestCase

@property (nonatomic, strong) NSXMLParser *xmlParser;
@property (nonatomic, strong) NSError *error;

@end

@implementation IGEpisodeParserTests

- (void)setUpClass
{
    [NSManagedObjectModel MR_setDefaultManagedObjectModel:[NSManagedObjectModel MR_managedObjectModelNamed:@"SITMOS.momd"]];
}

- (void)setUp
{
    [MagicalRecord setupCoreDataStackWithInMemoryStore];
    
    _xmlParser = [[NSXMLParser alloc] initWithData:[audioPodcastTestFeed dataUsingEncoding:NSUTF8StringEncoding]];
}

- (void)tearDown
{
    [MagicalRecord cleanUp];
    _xmlParser = nil;
}

- (void)testEpisodeParserSavesPropertiesPresentedInXML
{
    [self prepare];
    
    [IGEpisodeParser EpisodeParserWithXMLParser:_xmlParser success:^{
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:IGEpisodeParserDateFormat];
        
        IGEpisode *episode = [IGEpisode MR_findFirstByAttribute:@"title"
                                                      withValue:@"Episode 1"];
        
        GHAssertEqualObjects([episode title], @"Episode 1", @"The title should match the title presented in the episodes array");
        GHAssertEqualObjects([episode pubDate], [dateFormatter dateFromString:@"Tue, 10 Aug 2010 00:00:00 MST"], @"The pub date should match the pub date presented in the episodes array");
        GHAssertEqualObjects([episode summary], @"Achievements, Arizona Immigration Laws, and Annoying Social Networking Apps", @"The summary should match the summary presented in the episodes array");
        GHAssertEqualObjects([episode downloadURL], @"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3", @"The download url should match the url presented in the episodes array");
        GHAssertEqualObjects([[episode fileSize] stringValue], @"28900000", @"The file size should match the length presented in the episodes array");
        GHAssertEqualObjects([episode type], @"audio/mpeg", @"The type should match the type presented in the episodes array");
        GHAssertEqualObjects([episode duration], @"31:15", @"The duration should match the duration presented in the episodes array");
        GHAssertEqualObjects([episode fileName], @"Episode 1.mp3", @"The file name should be the episode title with the media type appended");
        
        [self notify:kGHUnitWaitStatusSuccess forSelector:_cmd];
    } failure:^(NSError *error) {
        
    }];
    
    [self waitForStatus:kGHUnitWaitStatusSuccess timeout:1.0];
}

@end
