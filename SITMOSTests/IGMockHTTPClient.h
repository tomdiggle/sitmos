//
//  IGMockHTTPClient.h
//  SITMOS
//
//  Created by Tom Diggle on 28/05/2013.
//
//

#import "IGHTTPClient.h"

@interface IGMockHTTPClient : IGHTTPClient

+ (IGMockHTTPClient *)sharedClient;

@end
