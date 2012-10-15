//
//  TDSlider.h
//  SITMOS
//
//  Created by Tom Diggle on 25/05/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface TDSlider : UISlider

// Used to set the height of the slider
@property (nonatomic) CGFloat height;

// Used to calculate how much fill the slider with the progress color
@property (nonatomic) float progress;

@property (strong, nonatomic) UIColor *backgroundColor;
@property (strong, nonatomic) UIColor *progressColor;

@end
