//
//  TDSlider.m
//  SITMOS
//
//  Created by Tom Diggle on 25/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "TDSlider.h"

@implementation TDSlider

@synthesize height = _height;
@synthesize progress = _progress;
@synthesize backgroundColor = _backgroundColor;
@synthesize progressColor = _progressColor;

- (id)initWithCoder:(NSCoder *)aDecoder
{
    if (!(self = [super initWithCoder:aDecoder]))
    {
        return nil;
    }
    
     _height = 12.0f;
    
    _backgroundColor = [UIColor colorWithRed:35/255.0
                                       green:35/255.0
                                        blue:35/255.0
                                       alpha:0.7];
    
    return self;
}

/**
 
 */
- (CGRect)trackRectForBounds:(CGRect)bounds
{
    CGRect result = [super trackRectForBounds:bounds];
    result.size.height = 0;
    return result;
}

/**
 
 */
- (void)drawRect:(CGRect)rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Create new bounds for the slider with the custom height 
    CGRect bounds = CGRectMake(self.bounds.origin.x, self.bounds.origin.y, self.bounds.size.width, _height);
    
    //
    CGFloat ins = 2.0;
    CGRect rectangle = CGRectInset(bounds, ins, ins);
    
    // Draw the slider
    [[UIColor colorWithRed:71/255.0
                     green:71/255.0
                      blue:71/255.0
                     alpha:1] set];
    CGFloat radius = rectangle.size.height / 2.0;
    CGMutablePathRef path = CGPathCreateMutable();
    CGPathMoveToPoint(path, NULL, CGRectGetMaxX(rectangle) - radius, ins);
    CGPathAddArc(path, NULL, radius+ins, radius+ins, radius, -M_PI/2.0, M_PI/2.0, true);
    CGPathAddArc(path, NULL, CGRectGetMaxX(rectangle) - radius, radius+ins, radius, M_PI/2.0, -M_PI/2.0, true);
    CGPathCloseSubpath(path);
    CGContextAddPath(context, path);
    CGContextSetLineWidth(context, 1);
    CGContextStrokePath(context);
    CGContextAddPath(context, path);
    CGContextClip(context);
    
    // Fill the rectangle with the background color
    [_backgroundColor set];
    CGContextFillRect(context, CGRectMake(rectangle.origin.x, rectangle.origin.y, rectangle.size.width, rectangle.size.height));
    
    // Calulate how much of the rectangle should be filled with the progress color
    float fillWidth = rectangle.size.width * (_progress / self.maximumValue);
    if (fillWidth > self.maximumValue)
    {
        fillWidth = self.maximumValue;
    }
    
    // Fill the rectangle with the progress color
    [_progressColor set];
    CGContextFillRect(context, CGRectMake(rectangle.origin.x, rectangle.origin.y, fillWidth, rectangle.size.height));
}

@end