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

#import "IGRSSXMLRequestOperation.h"

@implementation IGRSSXMLRequestOperation

+ (NSSet *)acceptableContentTypes
{
    return [NSSet setWithObjects:@"application/xml", @"text/xml", @"application/rss+xml", nil];
}

+ (IGRSSXMLRequestOperation *)RSSXMLRequestOperationWithRequest:(NSURLRequest *)request
                                                        success:(void (^)(NSURLRequest *, NSHTTPURLResponse *, NSXMLParser *))success
                                                        failure:(void (^)(NSURLRequest *, NSHTTPURLResponse *, NSError *, NSXMLParser *))failure
{
    AFXMLRequestOperation *operation = [IGRSSXMLRequestOperation XMLParserRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
        if (success) {
            success(request, response, XMLParser);
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSXMLParser *XMLParser) {
        if (failure) {
            failure(request, response, error, XMLParser);
        }
    }];
    
    return (IGRSSXMLRequestOperation *)operation;
}

+ (IGRSSXMLRequestOperation *)RSSXMLRequestOperationWithRequest:(NSURLRequest *)request
                                                     completion:(void (^)(NSURLRequest *, NSHTTPURLResponse *, NSXMLParser *, NSError *))completion
{
    AFXMLRequestOperation *operation = [IGRSSXMLRequestOperation XMLParserRequestOperationWithRequest:request success:^(NSURLRequest *request, NSHTTPURLResponse *response, NSXMLParser *XMLParser) {
        if (completion) {
            completion(request, response, XMLParser, nil);
        }
    } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, NSXMLParser *XMLParser) {
        if (completion) {
            completion(request, response, XMLParser, error);
        }
    }];
    
    return (IGRSSXMLRequestOperation *)operation;
}

@end
