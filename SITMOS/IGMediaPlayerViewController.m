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

#import "IGMediaPlayerViewController.h"

#import "IGMediaPlayer.h"
#import "IGMediaPlayerAsset.h"
#import "IGEpisode.h"
#import "IGHTTPClient.h"
#import "IGAudioPlayerViewController.h"
#import "IGVideoPlayerViewController.h"
#import "TestFlight.h"

@implementation IGMediaPlayerViewController

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
        if ([self.episode isAudio])
        {
            [self playAudio];
        }
        else
        {
            IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
            [mediaPlayer stop];
        }
    }
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self loadPlayerViewController];
}

#pragma mark - Seque

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"audioPlayerSegue"])
    {
        if (![self.episode isDownloaded] && ![IGHTTPClient allowCellularDataStreaming])
        {
            IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
            [mediaPlayer stop];
        
            UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"StreamingWithCellularDataTitle", nil)
                                                                message:NSLocalizedString(@"StreamingWithCellularDataMessage", nil)
                                                               delegate:self
                                                      cancelButtonTitle:NSLocalizedString(@"Cancel", "text label for cancel")
                                                      otherButtonTitles:NSLocalizedString(@"Stream", @"text label for stream"), nil];
            [alertView show];
        }
        else
        {
            [self playAudio];
        }
    
        IGAudioPlayerViewController *audioPlayerViewController = [segue destinationViewController];
        [audioPlayerViewController setTitle:[self.episode title]];
    }
    else if ([segue.identifier isEqualToString:@"videoPlayerSegue"])
    {
        IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
        [mediaPlayer stop];
        
        IGVideoPlayerViewController *videoPlayerViewController = [segue destinationViewController];
        [videoPlayerViewController setContentURL:[NSURL URLWithString:[self.episode downloadURL]]];
    }
}

#pragma mark - Load Player View Controller

/**
 * Loads the correct view controller depending on the current media type.
 */
- (void)loadPlayerViewController
{
    NSString *from = ([self.episode isDownloaded]) ? @"download" : @"stream";
    [TestFlight passCheckpoint:[NSString stringWithFormat:@"Playing %@ from %@", [self.episode title], from]];
        
    if ([self.episode isAudio])
    {
        [self performSegueWithIdentifier:@"audioPlayerSegue"
                                  sender:nil];
    }
    else if (![self.episode isAudio])
    {
        [self performSegueWithIdentifier:@"videoPlayerSegue"
                                  sender:self];
    }
}

#pragma mark - Play Audio

- (void)playAudio
{
    IGMediaPlayer *mediaPlayer = [IGMediaPlayer sharedInstance];
    IGMediaPlayerAsset *asset = nil;
    
    if ([mediaPlayer.asset shouldRestoreState])
    {
        asset = [mediaPlayer asset];
    }
    else
    {
        NSURL *contentURL = ([self.episode isDownloaded]) ? [self.episode fileURL] : [NSURL URLWithString:[self.episode downloadURL]];
        asset = [[IGMediaPlayerAsset alloc] initWithTitle:[self.episode title]
                                               contentURL:contentURL
                                                  isAudio:[self.episode isAudio]];
    }
    
    if ([[asset contentURL] isEqual:[[mediaPlayer asset] contentURL]] && ![mediaPlayer.asset shouldRestoreState])
    {
        return;
    }
    
    [mediaPlayer setStartFromTime:[[self.episode progress] floatValue]];
    
    [mediaPlayer startWithAsset:asset];
    
    [mediaPlayer.asset setShouldRestoreState:NO];
    
    [mediaPlayer setPausedBlock:^(Float64 currentTime) {
        NSManagedObjectContext *localContext = [NSManagedObjectContext MR_defaultContext];
        IGEpisode *localEpisode = [self.episode MR_inContext:localContext];
        [localEpisode setProgress:@(currentTime)];
        [localContext MR_saveToPersistentStoreAndWait];
    }];
    
    [mediaPlayer setStoppedBlock:^(Float64 currentTime, BOOL playbackEnded) {
        NSManagedObjectContext *localContext = [NSManagedObjectContext MR_defaultContext];
        IGEpisode *localEpisode = [self.episode MR_inContext:localContext];
        NSNumber *progress = @(currentTime);
        if (playbackEnded)
        {
            progress = @(0);
            [localEpisode markAsPlayed:playbackEnded];
        }
        [localEpisode setProgress:progress];
        [localContext MR_saveToPersistentStoreAndWait];
    }];
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0)
    {
        [self dismissViewControllerAnimated:YES
                                 completion:nil];
    }
    else if (buttonIndex == 1)
    {
        [self playAudio];
    }
}

@end
