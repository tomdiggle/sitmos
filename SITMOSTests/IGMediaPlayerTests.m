//
//  IGMediaPlayerTests.m
//  SITMOS
//
//  Created by Tom Diggle on 21/01/2013.
//
//

#import <GHUnitIOS/GHUnit.h>

#import "IGMediaPlayer.h"

@interface IGMediaPlayerTests : GHTestCase

@end

@implementation IGMediaPlayerTests

- (void)testThatNilIsNotAcceptableParameter
{
    GHAssertThrows([[IGMediaPlayer sharedInstance] startWithContentURL:nil], @"Media player should not be passed a nil url");
}

@end
