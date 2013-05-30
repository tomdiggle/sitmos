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

#import "IGVideoPlayerViewController.h"

@interface IGVideoPlayerViewController () <UIWebViewDelegate>

@property (nonatomic, strong) NSURL *contentURL;
@property (nonatomic, strong) UIWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator;

@end

@implementation IGVideoPlayerViewController

- (id)initWithContentURL:(NSURL *)contentURL
{
    if (!(self = [super init]))
    {
        return nil;
    }
    
    _contentURL = contentURL;
    
    return self;
}

- (void)viewDidLayoutSubviews
{
    self.view.backgroundColor = [UIColor redColor];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:[_contentURL absoluteString]];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"hide-media-player-icon"]
                                                                   style:UIBarButtonItemStyleBordered
                                                                  target:self
                                                                  action:@selector(hideMediaPlayer:)];
    
    _loadingIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [_loadingIndicator hidesWhenStopped];
    [_loadingIndicator startAnimating];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_loadingIndicator];
    
    _webView = [[UIWebView alloc] initWithFrame:self.view.bounds];
    [_webView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [_webView setDelegate:self];
    NSURLRequest *request = [NSURLRequest requestWithURL:_contentURL];
    [_webView loadRequest:request];
    [[self view] addSubview:_webView];
}

#pragma mark - UIWebViewDelegate Methods

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    NSString *title = [[self webView] stringByEvaluatingJavaScriptFromString:@"document.title"];
    [self setTitle:title];
    
    [_loadingIndicator stopAnimating];
}

#pragma mark - Hide Media Player

- (void)hideMediaPlayer:(id)sender
{
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

@end
