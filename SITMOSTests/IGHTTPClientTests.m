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

//#import "IGHTTPClient.h"

#import "IGMockHTTPClient.h"
#import <SenTestingKit/SenTestingKit.h>

#define HC_SHORTHAND
#import <OCHamcrest/OCHamcrest.h>

@interface IGHTTPClientTests : SenTestCase
@end

@implementation IGHTTPClientTests
{
    
}

- (void)testDevelopmentModeBaseURLIsCorrect {
    assertThat(IGDevelopmentBaseURL, equalTo(@"http://www.tomdiggle.com/"));
}

- (void)testDevelopmentModeAudioPodcastFeedURLIsCorrect {
    assertThat(IGDevelopmentAudioPodcastFeedURL, equalTo(@"http://www.tomdiggle.com/sitmos-development-feed/sitmos-audio-feed.xml"));
}

- (void)testDevelopmentModeVideoPodcastFeedURLIsCorrect {
    assertThat(IGDevelopmentVideoPodcastFeedURL, equalTo(@"http://www.tomdiggle.com/sitmos-development-feed/sitmos-video-feed.xml"));
}

- (void)testBaseURLIsCorrect {
    assertThat(IGBaseURL, equalTo(@"http://www.dereksweet.com/"));
}

- (void)testAudioPodcastFeedURLIsCorrect {
    assertThat(IGAudioPodcastFeedURL, equalTo(@"http://www.dereksweet.com/sitmos/sitmos.xml"));
}

- (void)testVideoPodcastFeedURLIsCorrect {
    assertThat(IGVideoPodcastFeedURL, equalTo(@"http://www.dereksweet.com/sitmos/sitmos-video-feed.xml"));
}

- (void)testBlahName {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    
    IGMockHTTPClient *mockHTTPClient = [IGMockHTTPClient sharedClient];
    [mockHTTPClient syncPodcastFeedsWithCompletion:^(BOOL success, NSError *error) {
        
        assertThat(error, notNilValue());
        dispatch_semaphore_signal(semaphore);
    }];
    
    while (dispatch_semaphore_wait(semaphore, DISPATCH_TIME_NOW))
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:10]];
}

@end
