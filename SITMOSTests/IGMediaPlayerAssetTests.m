//
//  IGMediaPlayerAssetTests.m
//  SITMOS
//
//  Created by Tom Diggle on 05/03/2013.
//
//

#import <GHUnitIOS/GHUnit.h>

#import "IGMediaPlayerAsset.h"

@interface IGMediaPlayerAssetTests : GHTestCase

@end

@implementation IGMediaPlayerAssetTests

- (void)testThatContentURLReturnsCorrectValue
{
    GHAssertThrows([IGMediaPlayerAsset mediaPlayerAssetWithURL:nil], @"Media Player Asset should not be passed a nil url");
}

@end
