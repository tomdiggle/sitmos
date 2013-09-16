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

#import "IGEpisode.h"

#import "IGDefines.h"
#import "NSDate+Helper.h"

#import <SenTestingKit/SenTestingKit.h>

#define HC_SHORTHAND
#import <OCHamcrestIOS/OCHamcrestIOS.h>

@interface IGEpisodeTests : SenTestCase

@property (nonatomic, strong) NSArray *feedItems;
@property (nonatomic, strong) IGEpisode *episodeOne;
@property (nonatomic, strong) IGEpisode *episodeTwo;

@end

@implementation IGEpisodeTests
{
    
}

- (void)setUp {
    [NSManagedObjectModel MR_setDefaultManagedObjectModel:[NSManagedObjectModel MR_managedObjectModelNamed:@"SITMOS.momd"]];
    [MagicalRecord setupCoreDataStackWithInMemoryStore];
    
    NSDictionary *episodeOneFeedItem = @{@"downloadURL": @"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3", @"duration": @"31:15", @"fileSize": @(28900000), @"mediaType": @"audio/mpeg", @"pubDate": @"Tue, 10 Aug 2010 08:00:00 BST", @"title": @"Episode 1", @"summary": @"Achievements, Arizona Immigration Laws, and Annoying Social Networking Apps"};
    NSDictionary *episodeTwoFeedItem = @{@"downloadURL": @"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_2.mp3", @"duration": @"36:52", @"fileSize": @(34000000), @"mediaType": @"audio/mpeg", @"pubDate": @"Sat, 21 Aug 2010 08:00:00 BST", @"title": @"Episode 2", @"summary": @"Dr, Laura vs. Dr. Satan, PC Gaming vs. Consoles, Black Ops Sheep and Twitter Questions - So Hide Your Kids, Hide your Wife!"};
    _feedItems = @[episodeOneFeedItem, episodeTwoFeedItem];

    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    [IGEpisode importPodcastFeedItems:_feedItems completion:^(BOOL success, NSError *error) {
        _episodeOne = [IGEpisode MR_findFirstByAttribute:@"title"
                                               withValue:@"Episode 1"];
        _episodeTwo = [IGEpisode MR_findFirstByAttribute:@"title"
                                               withValue:@"Episode 2"];
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

- (void)tearDown {
    [MagicalRecord cleanUp];
    _feedItems = nil;
    _episodeOne = nil;
}

- (void)testDateFormatIsCorrect {
    assertThat(IGDateFormatString, equalTo(@"EEE, dd MMM yyyy HH:mm:ss zzz"));
}

- (void)testEpisodeOneEntityNotNil {
    assertThat(_episodeOne, notNilValue());
}

- (void)testEpisodeOneDownloadURLPresentedInFeedItemsArrayIsSavedInEpisodeOneEntity {
    assertThat([_episodeOne downloadURL], equalTo(@"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_1.mp3"));
}

- (void)testEpisodeOneDurationPresentedInFeedItemsArrayIsSavedInEpisodeOneEntity {
    assertThat([_episodeOne duration], equalTo(@"31:15"));
}

- (void)testEpisodeOneFileSizePresentedInFeedItemsArrayIsSavedInEpisodeOneEntity {
    assertThat([_episodeOne fileSize], equalTo(@(28900000)));
}

- (void)testEpisodeOneMediaTypePresentedInFeedItemsArrayIsSavedInEpisodeOneEntity {
    assertThat([_episodeOne mediaType], equalTo(@"audio/mpeg"));
}

- (void)testEpisodeOnePubDatePresentedInFeedItemsArrayIsSavedInEpisodeOneEntity {
    assertThat([_episodeOne pubDate], equalTo([NSDate dateFromString:@"Tue, 10 Aug 2010 08:00:00 BST" withFormat:IGDateFormatString]));
}

- (void)testEpisodeOneSummaryPresentedInFeedItemsArrayIsSavedInEpisodeOneEntity {
    assertThat([_episodeOne summary], equalTo(@"Achievements, Arizona Immigration Laws, and Annoying Social Networking Apps"));
}

- (void)testEpisodeOneTitlePresentedInFeedItemsIsSavedInEpisodeOneEntity {
    assertThat([_episodeOne title], equalTo(@"Episode 1"));
}

- (void)testEpisodeOneHasCorrectFileName {
    assertThat([_episodeOne fileName], equalTo(@"Episode 1.mp3"));
}

- (void)testEpisodeOneIsAudio {
    assertThatBool([_episodeOne isAudio], equalToBool(YES));
}

- (void)testEpisodeOneIsMarkedAsPlayed {
    assertThatBool([_episodeOne isPlayed], equalTo([NSNumber numberWithBool:YES]));
}

- (void)testEpisodeOnePlayedStatusIsPlayed {
    assertThatInt([_episodeOne playedStatus], equalToInt(IGEpisodePlayedStatusPlayed));
}

- (void)testEpisodeTwoIsMarkedAsNotPlayed {
    assertThatBool([_episodeTwo isPlayed], equalTo([NSNumber numberWithBool:NO]));
}

- (void)testEpisodeTwoPlayedStatusIsUnplayed {
    assertThatInt([_episodeTwo playedStatus], equalToInt(IGEpisodePlayedStatusUnplayed));
}

- (void)testWhenTwoNewEpisodesGetSavedBothAreMarkedAsUnplayed {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    NSDictionary *episodeThreePointFiveFeedItem = @{@"downloadURL": @"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_3.5.mp3", @"duration": @"40:03", @"fileSize": @(37000000), @"mediaType": @"audio/mpeg", @"pubDate": @"Mon, 6 Sep 2010 08:00:00 BST", @"title": @"Episode 3.5", @"summary": @"War Between New and Used Games, Dead Rising 2 Case:Zero and Shank reviews, Black Ops trash talk take back, banning MMA in Canada and more Pure Pwnage news!"};
    NSDictionary *episodeFourFeedItem = @{@"downloadURL": @"https://s3.amazonaws.com/SITMOS_Audio_Episodes/SITMOS_EP_4.mp3", @"duration": @"32:56", @"fileSize": @(34000000), @"mediaType": @"audio/mpeg", @"pubDate": @"Fri, 17 Sep 2010 08:00:00 BST", @"title": @"Episode 4", @"summary": @"Dr, Laura vs. Dr. Satan, PC Gaming vs. Consoles, Black Ops Sheep and Twitter Questions - So Hide Your Kids, Hide your Wife!"};
    NSArray *newFeedItems = @[episodeThreePointFiveFeedItem, episodeFourFeedItem];
    
    [IGEpisode importPodcastFeedItems:newFeedItems completion:^(BOOL success, NSError *error) {
        IGEpisode *episodeThreePointFive = [IGEpisode MR_findFirstByAttribute:@"title"
                                                                    withValue:@"Episode 3.5"];
        IGEpisode *episodeFour = [IGEpisode MR_findFirstByAttribute:@"title"
                                                          withValue:@"Episode 4"];
        
        assertThatInt([episodeThreePointFive playedStatus], equalToInt(IGEpisodePlayedStatusUnplayed));
        assertThatInt([episodeFour playedStatus], equalToInt(IGEpisodePlayedStatusUnplayed));
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

@end
