//
//  EGORefreshTableHeaderView.m
//  Demo
//
//  Created by Devin Doty on 10/14/09October14.
//  Copyright 2009 enormego. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

#import "EGORefreshTableHeaderView.h"

@interface EGORefreshTableHeaderView ()

@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIActivityIndicatorView *activityView;

- (void)setState:(EGOPullRefreshState)aState;

@end

@implementation EGORefreshTableHeaderView

#pragma mark - Initializers

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame]))
    {
		return nil;
    }
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, frame.size.height - 40.0f, frame.size.width, 20.0f)];
    [label setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
    [label setFont:[UIFont systemFontOfSize:14.f]];
    [label setTextColor:[UIColor colorWithRed:179.0/255.0 green:179.0/255.0 blue:179.0/255.0 alpha:1.0]];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setTextAlignment:NSTextAlignmentCenter];
    [self addSubview:label];
    _statusLabel = label;
    
    UIActivityIndicatorView *view = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [view setFrame:CGRectMake(0.0f, frame.size.height - 40.0f, frame.size.width, 20.0f)];
    [view setColor:[UIColor colorWithRed:179.0/255.0 green:179.0/255.0 blue:179.0/255.0 alpha:1.0]];
    [self addSubview:view];
    _activityView = view;
    
    [self setState:EGOOPullRefreshNormal];
	
    return self;
}

#pragma mark - Setters

- (void)setState:(EGOPullRefreshState)aState
{	
	switch (aState)
    {
		case EGOOPullRefreshPulling:
			_statusLabel.text = NSLocalizedString(@"Release to refresh...", @"Release to refresh status");
			break;
            
		case EGOOPullRefreshNormal:
			_statusLabel.text = NSLocalizedString(@"Pull down to refresh...", @"Pull down to refresh status");
			[_activityView stopAnimating];
            _statusLabel.hidden = NO;
			break;
            
		case EGOOPullRefreshLoading:
			[_activityView startAnimating];
            _statusLabel.hidden = YES;
			break;
            
		default:
			break;
	}
	
	_state = aState;
}

#pragma mark - ScrollView Methods

- (void)egoRefreshScrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (_state == EGOOPullRefreshLoading)
    {
		CGFloat offset = MAX(scrollView.contentOffset.y * -1, 0);
		offset = MIN(offset, 60);
		scrollView.contentInset = UIEdgeInsetsMake(offset, 0.0f, 0.0f, 0.0f);
	} 
    else if (scrollView.isDragging)
    {
		BOOL loading = NO;
		if ([_delegate respondsToSelector:@selector(egoRefreshTableHeaderDataSourceIsLoading:)])
        {
			loading = [_delegate egoRefreshTableHeaderDataSourceIsLoading:self];
		}
		
		if (_state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !loading)
        {
			[self setState:EGOOPullRefreshNormal];
		} 
        else if (_state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !loading) 
        {
			[self setState:EGOOPullRefreshPulling];
		}
		
		if (scrollView.contentInset.top != 0) 
        {
			scrollView.contentInset = UIEdgeInsetsZero;
		}
	}
}

- (void)egoRefreshScrollViewDidEndDragging:(UIScrollView *)scrollView
{	
	BOOL loading = NO;
	if ([_delegate respondsToSelector:@selector(egoRefreshTableHeaderDataSourceIsLoading:)])
    {
		loading = [_delegate egoRefreshTableHeaderDataSourceIsLoading:self];
	}
	
	if (scrollView.contentOffset.y <= - 65.0f && !loading) 
    {
		if ([_delegate respondsToSelector:@selector(egoRefreshTableHeaderDidTriggerRefresh:)])
        {
			[_delegate egoRefreshTableHeaderDidTriggerRefresh:self];
		}
		
		[self setState:EGOOPullRefreshLoading];
        
        [UIView animateWithDuration:0.3 animations:^{
            [scrollView setContentInset:UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f)];
        }];
        
	}
}

- (void)egoRefreshScrollViewDataSourceDidFinishedLoading:(UIScrollView *)scrollView 
{
    [UIView animateWithDuration:0.3 animations:^{
        [scrollView setContentInset:UIEdgeInsetsZero];
    } completion:^(BOOL finished){
        [self setState:EGOOPullRefreshNormal];
    }];
}

@end