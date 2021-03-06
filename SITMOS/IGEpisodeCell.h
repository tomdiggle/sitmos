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

#import "IGEpisode.h"

#import <UIKit/UIKit.h>

/**
 * The IGEpisodeCell class defines the attributes and behaviour of the cells that appear in IGEpisodesListViewController's UITableView.
 */

@interface IGEpisodeCell : UITableViewCell

/**
 * Returns the title of the episode.
 */
@property (nonatomic, copy) NSString *title;

/**
 * Returns the summary of the episode.
 *
 * @discussion Only two lines of the summary is shown and it is truncated by NSLineBreakByTruncatingTail. 
 */
@property (nonatomic, copy) NSString *summary;

/**
 * Returns the date the episode was published.
 *
 * @discussion The pub date is formatted with the timeLeft variable like 03 Jan 2011 - 03:33.
 *
 * @see timeLeft
 */
@property (nonatomic, strong) NSDate *pubDate;

/**
 * Returns the amount of time left remaining in the episode.
 *
 * @discussion The amount of time left is formatted with the pub date like 03 Jan 2011 - 03:33.
 *
 * @see pubDate
 */
@property (nonatomic, copy) NSString *timeLeft;

/**
 * Returns the download url of the episode.
 *
 * @discussion Used to search for the download operation if downloadStatus is set to IGEpisodeDownloadStatusDownloading. 
 */
@property (nonatomic, strong) NSURL *downloadURL;

/**
 * Returns the button used to display the show notes view controller.
 */
@property (nonatomic, weak) IBOutlet UIButton *showNotesButton;

/**
 * Returns the download status of the episode.
 */
@property (nonatomic, assign) IGEpisodeDownloadStatus downloadStatus;

/**
 * Returns the played status of the episode.
 */
@property (nonatomic, assign) IGEpisodePlayedStatus playedStatus;

@end
