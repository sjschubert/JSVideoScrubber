//
//  UIImage+JSScrubber.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 11/24/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import "UIImage+JSScrubber.h"

@implementation UIImage (JSScrubber)

+ (UIImage *)cropImageToRect:(CGRect)rect image:(UIImage *)source
{
    UIGraphicsBeginImageContext(rect.size);
    
	CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0, rect.size.height *2);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGContextClipToRect(context, rect);
    
    [source drawAtPoint:CGPointZero];
    
	UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
    
    return output;
}

+ (UIImage *)drawImageIntoRect:(CGSize)size offset:(CGPoint)offset image:(UIImage *)source
{
    UIGraphicsBeginImageContext(size);
    
	CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGContextTranslateCTM(context, 0, size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
	[source drawAtPoint:offset];
    
	UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();

    return output;
}

+ (UIImage *) drawResizableImage:(UIImage *) image toSize:(CGSize) size
{
    UIGraphicsBeginImageContext(size);
    
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    
	UIImage *output = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
    
    return output;
}

- (UIImage*) applyMask:(UIImage *) mask
{
    UIImage *resizedMask = [UIImage drawResizableImage:mask toSize:self.size];
    
    CGImageRef imageReference = self.CGImage;
    CGImageRef maskReference = resizedMask.CGImage;

    //NSLog(@"image dims: %f x %f", resizedMask.size.width, resizedMask.size.height);
    
    CGImageRef imageMask = CGImageMaskCreate(CGImageGetWidth(maskReference),
                                             CGImageGetHeight(maskReference),
                                             CGImageGetBitsPerComponent(maskReference),
                                             CGImageGetBitsPerPixel(maskReference),
                                             CGImageGetBytesPerRow(maskReference),
                                             CGImageGetDataProvider(maskReference),
                                             NULL,
                                             YES);
    
    CGImageRef maskedReference = CGImageCreateWithMask(imageReference, imageMask);
    CGImageRelease(imageMask);
    
    UIImage *maskedImage = [UIImage imageWithCGImage:maskedReference];
    CGImageRelease(maskedReference);
    
    return maskedImage;
}

- (UIImage *) flipImageVertically
{
    CGFloat width = CGImageGetWidth(self.CGImage);
    CGFloat height = CGImageGetHeight(self.CGImage);
    
    UIGraphicsBeginImageContext(CGSizeMake(width, height));
    CGContextRef context = UIGraphicsGetCurrentContext();
    
	CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);

    [self drawAtPoint:CGPointZero];
    
    UIImage *flipedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return flipedImage;
}

@end
