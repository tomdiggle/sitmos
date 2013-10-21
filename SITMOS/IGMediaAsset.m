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

#import "IGMediaAsset.h"

@interface IGMediaAsset () <NSCoding>

@property (readwrite, nonatomic, copy) NSString *title;
@property (readwrite, nonatomic, copy) NSURL *contentURL;
@property (readwrite, nonatomic, assign, getter = isAudio) BOOL audio;

@end

@implementation IGMediaAsset

- (id)initWithTitle:(NSString *)title contentURL:(NSURL *)contentURL isAudio:(BOOL)audio
{
    if (!(self = [super init])) return nil;
    
    self.title = title;
    self.contentURL = contentURL;
    self.audio = audio;
    
    return self;
}

#pragma mark - NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
    NSString *title = [decoder decodeObjectForKey:@"IGMediaPlayerAssetTitle"];
    NSURL *contentURL = [decoder decodeObjectForKey:@"IGMediaPlayerAssetContentURL"];
    BOOL isAudio = [decoder decodeBoolForKey:@"IGMediaPlayerAssetIsAudio"];
    
    self = [self initWithTitle:title
                    contentURL:contentURL
                       isAudio:isAudio];
    
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
    [encoder encodeObject:self.title forKey:@"IGMediaPlayerAssetTitle"];
    [encoder encodeObject:self.contentURL forKey:@"IGMediaPlayerAssetContentURL"];
    [encoder encodeBool:self.isAudio forKey:@"IGMediaPlayerAssetIsAudio"];
}

@end
