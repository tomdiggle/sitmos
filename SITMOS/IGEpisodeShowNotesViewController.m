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

#import "IGEpisodeShowNotesViewController.h"

#import "IGEpisode.h"
#import "UIViewController+IGNowPlayingButton.h"
#import "UIImageView+AFNetworking.h"
#import "NSDate+Helper.h"

@interface IGEpisodeShowNotesViewController ()

@property (nonatomic, weak) IBOutlet UIImageView *episodeImageView;
@property (nonatomic, weak) IBOutlet UIImageView *episodeDownloadedImageView;
@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *pubDateAndTimeLeftLabel;
@property (nonatomic, weak) IBOutlet UILabel *pubDateLabel;
@property (nonatomic, weak) IBOutlet UILabel *durationLabel;
@property (nonatomic, weak) IBOutlet UILabel *fileSizeLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;

@end

@implementation IGEpisodeShowNotesViewController

#pragma mark - Setup

- (void)setupLabels
{
    NSString *pubDate = [NSDate stringFromDate:[self.episode pubDate] withFormat:@"dd MMM yyyy"];
    [self.titleLabel setText:[self.episode title]];
    [self.pubDateAndTimeLeftLabel setText:[NSString stringWithFormat:@"%@ - %@", pubDate, [self.episode duration]]];
    [self.durationLabel setText:[self.episode duration]];
    [self.pubDateLabel setText:[NSDate stringFromDate:[self.episode pubDate] withFormat:@"dd MMM yyyy"]];
    [self.fileSizeLabel setText:[self.episode readableFileSize]];
    [self.summaryLabel setText:[self.episode summary]];
    [self.episodeImageView setImageWithURL:[NSURL URLWithString:[self.episode imageURL]] placeholderImage:[UIImage imageNamed:@"episode-image-placeholder"]];
    
    if ([self.episode isDownloaded])
    {
        [self.episodeDownloadedImageView setHidden:NO];
    }
}

#pragma mark - State Preservation and Restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    
    [coder encodeObject:[[self.episode objectID] URIRepresentation] forKey:@"IGEpisodeURI"];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    
    NSURL *episodeURI = [coder decodeObjectForKey:@"IGEpisodeURI"];
    NSManagedObjectContext *context = [NSManagedObjectContext MR_defaultContext];
    NSManagedObjectID *episodeObjectID = [[context persistentStoreCoordinator] managedObjectIDForURIRepresentation:episodeURI];
    if (episodeObjectID)
    {
        self.episode = (IGEpisode *)[context objectWithID:episodeObjectID];
        [self setupLabels];
    }
}

#pragma mark - View Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupLabels];
}

#pragma mark - Orientation Support

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
