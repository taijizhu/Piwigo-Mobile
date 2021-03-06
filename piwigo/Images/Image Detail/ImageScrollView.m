//
//  ImageScrollView.m
//  piwigo
//
//  Created by Spencer Baker on 2/21/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import "ImageScrollView.h"

@interface ImageScrollView() <UIScrollViewDelegate>

@end

@implementation ImageScrollView

-(instancetype)init
{
	self = [super init];
	if(self)
	{
		self.showsVerticalScrollIndicator = NO;
		self.showsHorizontalScrollIndicator = NO;
		self.bouncesZoom = YES;
		self.decelerationRate = UIScrollViewDecelerationRateFast;
		self.delegate = self;
		
		self.maximumZoomScale = 2.5;
		self.minimumZoomScale = 1.0;
		
        // Image previewed
		self.imageView = [UIImageView new];
		self.imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.imageView.backgroundColor = [UIColor piwigoGray];
		[self addSubview:self.imageView];

        // Play button above posters of movie
        self.playImage = [UIImageView new];
        UIImage *play = [UIImage imageNamed:@"videoPlay"];
        self.playImage.image = [play imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
        self.playImage.tintColor = [UIColor piwigoWhiteCream];
        self.playImage.hidden = YES;
        self.playImage.translatesAutoresizingMaskIntoConstraints = NO;
        self.playImage.contentMode = UIViewContentModeScaleAspectFit;
        [self addSubview:self.playImage];
        [self addConstraints:[NSLayoutConstraint constraintView:self.playImage toSize:CGSizeMake(50, 50)]];
        [self addConstraints:[NSLayoutConstraint constraintCenterView:self.playImage]];
}
	return self;
}

-(UIView*)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
	return self.imageView;
}

@end
