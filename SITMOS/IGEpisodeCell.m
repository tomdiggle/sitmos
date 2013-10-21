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

#import "IGEpisodeCell.h"

#import "IGNetworkManager.h"
#import "NSDate+Helper.h"

static void * IGTaskStateChangedContext = &IGTaskStateChangedContext;
static void * IGTaskReceivedDataContext = &IGTaskReceivedDataContext;

@interface IGEpisodeCell ()

@property (nonatomic, weak) IBOutlet UILabel *titleLabel;
@property (nonatomic, weak) IBOutlet UILabel *summaryLabel;
@property (nonatomic, weak) IBOutlet UILabel *pubDateAndTimeLeftLabel;
@property (nonatomic, weak) IBOutlet UILabel *downloadProgressLabel;
@property (nonatomic, weak) IBOutlet UIImageView *playedStatusImageView;
@property (nonatomic, weak) IBOutlet UIImageView *episodeDownloadedImageView;
@property (nonatomic, weak) IBOutlet UIProgressView *downloadProgressView;
@property (nonatomic, weak) IBOutlet UIButton *downloadButton;
@property (nonatomic, strong) NSURLSessionDownloadTask *downloadTask;
@property (nonatomic, strong) NSProgress *downloadProgress;
@property (nonatomic, strong) NSLayoutConstraint *pubDateAndTimeLeftLayoutConstraint;

@end

@implementation IGEpisodeCell

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"<Episode Title: %@>", self.title];
}

#pragma mark - Initializers

- (void)awakeFromNib
{
    self.pubDateAndTimeLeftLayoutConstraint = [NSLayoutConstraint constraintWithItem:self.pubDateAndTimeLeftLabel
                                                                           attribute:NSLayoutAttributeLeading
                                                                           relatedBy:NSLayoutRelationEqual
                                                                              toItem:self.contentView
                                                                           attribute:NSLayoutAttributeLeading
                                                                          multiplier:1
                                                                            constant:15];
    [self addConstraint:self.pubDateAndTimeLeftLayoutConstraint];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(downloadTaskDidStart:)
                                                 name:AFNetworkingTaskDidStartNotification
                                               object:nil];
}

#pragma mark - Layout

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    NSURLSessionDownloadTask *task = [IGNetworkManager downloadTaskForURL:self.downloadURL];
    if (task)
    {
        self.downloadTask = task;
        [self layoutForDownloadTaskRunning];
    }
    else if (self.downloadTask && ![[self.downloadTask.originalRequest URL] isEqual:self.downloadURL])
    {
        // When the cell gets re-used and the re-used cell is now not downloading we need to update the UI.
        [self layoutForDownloadTaskNotRunning];
    }
}

- (void)layoutForDownloadTaskRunning
{
    if (!self.downloadProgress)
    {
        self.downloadProgress = [[NSProgress alloc] initWithParent:nil userInfo:@{NSProgressKindFile: NSProgressFileOperationKindDownloading}];
        self.downloadProgress.kind = NSProgressKindFile;
        self.downloadProgress.totalUnitCount = [self.downloadTask countOfBytesExpectedToReceive];
        self.downloadProgress.completedUnitCount = [self.downloadTask countOfBytesReceived];
    }
    
    self.downloadProgressView.progress = [self.downloadProgress fractionCompleted];
    self.downloadProgressLabel.text = ([self.downloadProgress fractionCompleted] == 0) ? NSLocalizedString(@"Loading", nil) : self.downloadProgress.localizedAdditionalDescription;
    
    self.titleLabel.textColor = [self unplayedColor];
    
    [self.downloadProgressView setHidden:NO];
    [self.downloadProgressLabel setHidden:NO];
    [self.downloadButton setHidden:NO];
    [self.summaryLabel setHidden:YES];
    [self.playedStatusImageView setHidden:YES];
    [self.pubDateAndTimeLeftLabel setHidden:YES];
    [self.showNotesButton setHidden:YES];
    
    [self updateDownloadButtonImageForSessionState:NSURLSessionTaskStateRunning];
    
    [self.downloadTask addObserver:self forKeyPath:@"state" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:IGTaskStateChangedContext];
    [self.downloadTask addObserver:self forKeyPath:@"countOfBytesReceived" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:IGTaskReceivedDataContext];
}

- (void)layoutForDownloadTaskNotRunning
{
    self.titleLabel.textColor = (self.playedStatus == IGEpisodePlayedStatusPlayed) ? [self playedColor] : [self unplayedColor];
    
    [self.summaryLabel setHidden:NO];
    [self.playedStatusImageView setHidden:NO];
    [self.pubDateAndTimeLeftLabel setHidden:NO];
    [self.showNotesButton setHidden:NO];
    [self.downloadProgressView setHidden:YES];
    [self.downloadProgressLabel setHidden:YES];
    [self.downloadButton setHidden:YES];
    
    @try
    {
        [self.downloadTask removeObserver:self forKeyPath:@"state" context:IGTaskStateChangedContext];
        [self.downloadTask removeObserver:self forKeyPath:@"countOfBytesReceived" context:IGTaskReceivedDataContext];
    } @catch (NSException *exception) {}
    
    self.downloadProgressView.progress = 0;
    self.downloadTask = nil;
    self.downloadProgress = nil;
}

#pragma mark - Setters

- (void)setDownloadStatus:(IGEpisodeDownloadStatus)downloadStatus
{
    if (downloadStatus == IGEpisodeDownloadStatusDownloaded)
    {
        [self.episodeDownloadedImageView setHidden:NO];
    }
    else
    {
        [self.episodeDownloadedImageView setHidden:YES];
    }
    
    _downloadStatus = downloadStatus;
    
    [self setNeedsLayout];
}

- (void)setPlayedStatus:(IGEpisodePlayedStatus)playedStatus
{
    if (playedStatus == IGEpisodePlayedStatusUnplayed)
    {
        [self.playedStatusImageView setImage:[UIImage imageNamed:@"episode-unplayed-icon"]];
        [self.pubDateAndTimeLeftLayoutConstraint setConstant:28];
        self.titleLabel.textColor = [self unplayedColor];
    }
    else if (playedStatus == IGEpisodePlayedStatusHalfPlayed)
    {
        [self.playedStatusImageView setImage:[UIImage imageNamed:@"episode-half-played-icon"]];
        [self.pubDateAndTimeLeftLayoutConstraint setConstant:28];
        self.titleLabel.textColor = [self unplayedColor];
    }
    else
    {
        [self.pubDateAndTimeLeftLayoutConstraint setConstant:15];
        [self.playedStatusImageView setImage:nil];
        self.titleLabel.textColor = [self playedColor];
    }
    
    _playedStatus = playedStatus;
    
    [self setNeedsLayout];
}

- (void)setTitle:(NSString *)title
{
    if ([title isEqualToString:_title]) return;
    
    _title = title;
    
    [_titleLabel setText:title];
}

- (void)setSummary:(NSString *)summary
{
    if ([summary isEqualToString:_summary]) return;
    
    _summary = summary;
    
    [_summaryLabel setText:summary];
}

- (void)setPubDate:(NSDate *)pubDate
{
    if ([pubDate isEqualToDate:_pubDate]) return;
    
    _pubDate = pubDate;
    
    [_pubDateAndTimeLeftLabel setText:[NSString stringWithFormat:@"%@ - %@", [NSDate stringFromDate:pubDate withFormat:@"dd MMM yyyy"], _timeLeft]];
}

- (void)setTimeLeft:(NSString *)timeLeft
{
    if ([timeLeft isEqualToString:_timeLeft]) return;
    
    _timeLeft = timeLeft;
    
    [_pubDateAndTimeLeftLabel setText:[NSString stringWithFormat:@"%@ - %@", [NSDate stringFromDate:_pubDate withFormat:@"dd MMM yyyy"], timeLeft]];
}

#pragma mark - Color's for the episode title label

- (UIColor *)playedColor
{
    return [UIColor colorWithRed:0.701 green:0.701 blue:0.701 alpha:1];
}

- (UIColor *)unplayedColor
{
    return [UIColor blackColor];
}

#pragma mark - Download Button

- (IBAction)pauseOrResumeDownload:(id)sender
{
    NSURLSessionDownloadTask *sessionTask = [IGNetworkManager downloadTaskForURL:self.downloadURL];
    if (sessionTask.state == NSURLSessionTaskStateRunning)
    {
        [sessionTask suspend];
        
        [self updateDownloadButtonImageForSessionState:NSURLSessionTaskStateSuspended];
    }
    else
    {
        [sessionTask resume];
        
        [self updateDownloadButtonImageForSessionState:NSURLSessionTaskStateRunning];
    }
}

- (void)updateDownloadButtonImageForSessionState:(NSURLSessionTaskState)state
{
    if (state == NSURLSessionTaskStateRunning)
    {
        [self.downloadButton setImage:[UIImage imageNamed:@"download-pause-button"]
                             forState:UIControlStateNormal];
        [self.downloadButton setAccessibilityLabel:NSLocalizedString(@"PauseDownload", nil)];
    }
    else
    {
        [self.downloadButton setImage:[UIImage imageNamed:@"download-resume-button"]
                             forState:UIControlStateNormal];
        [self.downloadButton setAccessibilityLabel:NSLocalizedString(@"ResumeDownload", nil)];
    }
}

#pragma mark - Notification

- (void)downloadTaskDidStart:(NSNotification *)notification
{
    NSURLSessionDownloadTask *task = (NSURLSessionDownloadTask *)notification.object;
    if ([[task.originalRequest URL] isEqual:self.downloadURL])
    {
        self.downloadTask = task;
        [self layoutForDownloadTaskRunning];
    }
}

#pragma mark - NSKeyValueObserving

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if (context == IGTaskStateChangedContext && [keyPath isEqualToString:@"state"])
    {
        NSURLSessionTask *task = (NSURLSessionTask *)object;
        if (![[task.originalRequest URL] isEqual:self.downloadURL])
        {
            return;
        }
        
        switch (task.state)
        {
            case NSURLSessionTaskStateRunning:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self layoutForDownloadTaskRunning];
                });
                break;
            }
            case NSURLSessionTaskStateSuspended:
            {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self updateDownloadButtonImageForSessionState:NSURLSessionTaskStateSuspended];
                });
                break;
            }
            case NSURLSessionTaskStateCompleted:
            {
                if (![object error])
                {
                    self.downloadStatus = IGEpisodeDownloadStatusDownloaded;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self layoutForDownloadTaskNotRunning];
                });
                
                @try
                {
                    [object removeObserver:self forKeyPath:@"state" context:IGTaskStateChangedContext];
                    [object removeObserver:self forKeyPath:@"countOfBytesReceived" context:IGTaskReceivedDataContext];
                } @catch (NSException *exception) {}
                break;
            }
            default:
                break;
        }
    }
    else if (context == IGTaskReceivedDataContext && [keyPath isEqualToString:@"countOfBytesReceived"])
    {
        NSURLSessionTask *task = (NSURLSessionTask *)object;
        if (![[task.originalRequest URL] isEqual:self.downloadURL])
        {
            return;
        }

        self.downloadProgress.totalUnitCount = task.countOfBytesExpectedToReceive;
        self.downloadProgress.completedUnitCount = task.countOfBytesReceived;
            
        dispatch_async(dispatch_get_main_queue(), ^{
            self.downloadProgressView.progress = self.downloadProgress.fractionCompleted;
            self.downloadProgressLabel.text = self.downloadProgress.localizedAdditionalDescription;
        });
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end
