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

#import <Foundation/Foundation.h>

@interface IGMediaAsset : NSObject

/**
 * The title with which the asset was initialized. (read-only)
 */
@property (readonly, nonatomic, copy) NSString *title;

/**
 * The URL with which the asset was initialized. (read-only)
 */
@property (readonly, nonatomic, copy) NSURL *contentURL;

/**
 * Returns YES is media is audio, NO otherwise. (read-only)
 */
@property (readonly, nonatomic, assign, getter = isAudio) BOOL audio;

/**
 * @name Initialization
 */

/**
 * Initializes a new media asset with the specified title, content url and is audio. This is the designated initializer.
 *
 * @param title The title of the media playing.
 * @param contentURL The location of the media
 */
- (id)initWithTitle:(NSString *)title
         contentURL:(NSURL *)contentURL
            isAudio:(BOOL)audio;

@end
