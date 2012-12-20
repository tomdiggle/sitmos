//
//  IGMediaPlayerTests.m
//  SITMOS
//
//  Created by Tom Diggle on 20/12/2012.
//
//

#import "IGMediaPlayerTests.h"
#import "IGMediaPlayer.h"

@implementation IGMediaPlayerTests

- (void)testThatNilIsNotAcceptableParameter
{
    STAssertThrows([[IGMediaPlayer sharedInstance] startWithContentURL:nil], @"Media player should not be passed a nil url");
}

@end
