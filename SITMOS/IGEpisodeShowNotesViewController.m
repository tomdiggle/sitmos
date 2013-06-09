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

#import "IGEpisodeShowNotesViewController.h"

#import "IGEpisode.h"
#import "IGEpisodeShowNotesHeader.h"
#import "IGEpisodeShowNotesBody.h"
#import "IGDefines.h"

@interface IGEpisodeShowNotesViewController ()

@property (nonatomic, strong) IGEpisode *episode;

@end

@implementation IGEpisodeShowNotesViewController

- (id)initWithEpisode:(IGEpisode *)episode
{
    if (!(self = [super init])) return nil;
    
    _episode = episode;
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:NSLocalizedString(@"ShowNotes", @"text label for show notes")];
    
    IGEpisodeShowNotesHeader *header = [[IGEpisodeShowNotesHeader alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 56.f)];
    [header setTitle:[_episode title]];
    [header setPubDate:[_episode pubDate]];
    [header setDuration:[_episode duration]];
    [header setPlayedStatus:[_episode playedStatus]];
    [header setDownloadStatus:[_episode downloadStatus]];
    [[self view] addSubview:header];
    
    IGEpisodeShowNotesBody *showNotes = [[IGEpisodeShowNotesBody alloc] initWithFrame:CGRectZero];
    [showNotes setDuration:[_episode duration]];
    [showNotes setFileSize:[_episode readableFileSize]];
    [showNotes setPubDate:[_episode pubDate]];
    [showNotes setAudio:[_episode isAudio]];
    [showNotes setSummary:[_episode summary]];
    
    UIScrollView *body = [[UIScrollView alloc] initWithFrame:CGRectMake(0, header.frame.size.height, self.view.bounds.size.width, self.view.bounds.size.height - header.frame.size.height)];
    [body setBackgroundColor:kRGBA(245, 245, 245, 1)];
    [body setContentSize:self.view.bounds.size];
    [body addSubview:showNotes];
    
    [[self view] addSubview:body];
}

#pragma mark - Orientation Support

- (NSUInteger)supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskPortrait;
}

@end
