//
//  UIImage+JSScrubber.h
//  JSVideoScrubber
//
//  Created by jaminschubert on 11/24/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIImage (JSScrubber)

+ (UIImage *) drawResizableImage:(UIImage *) image toSize:(CGSize) size;
+ (UIImage *) drawImageIntoRect:(CGSize)size offset:(CGPoint)offset image:(UIImage *)source;
- (UIImage*) applyMask:(UIImage *) mask;
- (UIImage *) flipImageVertically;

@end
