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

@class DACircularProgressView;

@protocol IGEpisodeTableViewCellDelegate;

/**
 * The IGEpisodeTableViewCell class defines the attributes and behaviour of the cells that appear in IGEpisodesListViewController's UITableView.
 */

@interface IGEpisodeTableViewCell : UITableViewCell

/**
 * Returns the label used for the episode's title.
 */
@property (strong, nonatomic) IBOutlet UILabel *episodeTitleLabel;

/**
 * Returns the label used for the episode's published date and duration.
 */
@property (strong, nonatomic) IBOutlet UILabel *episodeDateAndDurationLabel;

/**
 * Returns the download episode button (UIButton object) of the table cell. The image is set by setting the downloadStatus object.
 *
 * @see downloadStatus
 */
@property (strong, nonatomic) IBOutlet UIButton *downloadEpisodeButton;

/**
 * Returns the more info button of the table cell.
 */
@property (strong, nonatomic) IBOutlet UIButton *moreInfoButton;

/**
 * Returns the helper icon image view of the table cell.
 *
 * @see playedStatus
 */
@property (strong, nonatomic) IBOutlet UIImageView *playedStatusIconImageView;

/**
 * Returns the download progress view of the table cell.
 *
 * Returns the download progress view (DACircularProgressView object) of the table cell. The download progress view is only visible when the episode is downloading.
 */
@property (strong, nonatomic) IBOutlet DACircularProgressView *downloadProgressView;

/**
 * Returns the download status of the episode.
 */
@property (nonatomic) IGEpisodeDownloadStatus downloadStatus;

/**
 * Returns the played status of the episode.
 */
@property (nonatomic) IGEpisodePlayedStatus playedStatus;

/**
 * The object that acts as the delegate of the receiving episode table view cell.
 *
 * The delegate must adopt the IGEpisodeTableViewCellDelegate protocol. The delegate is not retained.
 */
@property (weak, nonatomic) id <IGEpisodeTableViewCellDelegate> delegate;

@end

/**
 * The delegate of IGEpisodeTableViewCell object must adopt the IGEpisodeTableViewCellDelegate protocol.
 */

@protocol IGEpisodeTableViewCellDelegate <NSObject>

/**
 * Asks the delegate to display more info about the episode with the given title.
 *
 * @param episodeTableViewCell The episode table view cell object requesting the information.
 * @param title The title of the episode.
 */
- (void)igEpisodeTableViewCell:(IGEpisodeTableViewCell *)episodeTableViewCell displayMoreInfoAboutEpisodeWithTitle:(NSString *)title;

/**
 * Asks the delegate to download the episode with the given title.d
 *
 * @param episodeTableViewCell The episode table view cell object requesting the information.
 * @param title The title of the episode.
 */
- (void)igEpisodeTableViewCell:(IGEpisodeTableViewCell *)episodeTableViewCell downloadEpisodeWithTitle:(NSString *)title;

@end
