/**
 * Copyright (c) 2012, Tom Diggle
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

/**
 * Runs the initial setup of the app by registering the default settings and if there are any episodes of SITMOS are already stored on the iPod it
 * will ask the user if they want to import them into the app.
 */

@interface IGInitialSetup : NSObject

/**
 * Allocates a new instance of the class, sends it an init message, begins the initial setup and returns the initialized object.
 *
 * @return the initialized object.
 */
+ (IGInitialSetup *)runInitialSetup;

/**
 * Creates the episodes directory in <APP>/Library/Caches
 */
+ (void)createEpisodesDirectory;

/**
 * @return the app's caches directory <APP>/Library/Caches
 */
+ (NSURL *)cachesDirectory;

/**
 * @return the directory where all downloaded episodes are stored <APP>/Library/Caches/Episodes
 */
+ (NSURL *)episodesDirectory;

@end
