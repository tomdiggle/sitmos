//
//  IGMockHTTPClient.m
//  SITMOS
//
//  Created by Tom Diggle on 28/05/2013.
//
//

#import "IGMockHTTPClient.h"

@implementation IGMockHTTPClient

+ (IGMockHTTPClient *)sharedClient
{
    static IGMockHTTPClient *sharedClient = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedClient = [[self alloc] init];
    });
    return sharedClient;
}

- (void)enqueueBatchOfHTTPRequestOperations:(NSArray *)operations
                              progressBlock:(void (^)(NSUInteger, NSUInteger))progressBlock
                            completionBlock:(void (^)(NSArray *))completionBlock
{
//    NSLog(@"Here");
}

@end
