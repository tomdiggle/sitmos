//
//  NSString+MD5.h
//  NSStringMD5
//
//  Created by Guilherme Andrade on 12/11/11.
//  Copyright (c) 2011 2thinkers. All rights reserved.
//  
// http://stackoverflow.com/a/3104362
//

#import <Foundation/Foundation.h>

@interface NSString (MD5)

+ (NSString *)MD5Hash:(NSString *)input;
- (NSString *)MD5Hash;

@end
