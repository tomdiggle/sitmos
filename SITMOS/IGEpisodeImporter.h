/**
 * Copyright (c) 2012-2013, Tom Diggle
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

/**
 * The IGEpisodeImporter class will import any episodes of Stuck in the Middle of Somewhere that are stored in the iPod library.
 */

@interface IGEpisodeImporter : NSObject

/**
 * Returns an array of media items of Stuck in the Middle of Somewhere stored in the iPod library, or an empty array if none exist.
 */
+ (NSArray *)episodesOnDevice;

/**
 * Creates and returns an IGEpisodeImporter object and sets the specified episodes to import, destination directory and completion block.
 *
 * @param episodes Use the method episodesOnDevice to get an array of episodes to import.
 * @param destinationDirectory The directory the episodes will be located when imported.
 * @param completion The completion handler block to execute. 
 *
 * @see episodesOnDevice
 */
+ (instancetype)importEpisodes:(NSArray *)episodes destinationDirectory:(NSURL *)destinationDirectory completion:(void (^)(NSUInteger episodesImported, BOOL success, NSError *error))completion;

/**
 * Will start import.
 */
- (void)importEpisodes;

@end
