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
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    
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
    CGFloat width = self.size.width;
    CGFloat height = self.size.height;
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, height), NO, 0.0f);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
	CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);

    [self drawAtPoint:CGPointZero];
    
    UIImage *flipedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return flipedImage;
}

static void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight)
{
    float fw, fh;
    
    if (ovalWidth == 0 || ovalHeight == 0) {
        CGContextAddRect(context, rect);
        return;
    }
    
    CGContextSaveGState(context);
    CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
    CGContextScaleCTM (context, ovalWidth, ovalHeight);
    
    fw = CGRectGetWidth (rect) / ovalWidth;
    fh = CGRectGetHeight (rect) / ovalHeight;
    
    CGContextMoveToPoint(context, fw, fh/2);
    CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
    CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
    CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
    CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
    CGContextClosePath(context);
    
    CGContextRestoreGState(context);
}

- (UIImage *)maskWithCornerSize:(CGSize)size
{
    UIImage * newImage = nil;
    
    if( nil != self)
    {
        @autoreleasepool {
            int w = self.size.width;
            int h = self.size.height;
            
            CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
            CGContextRef context = CGBitmapContextCreate(NULL, w, h, 8, 4 * w, colorSpace, kCGImageAlphaPremultipliedFirst);
            
            CGContextBeginPath(context);
            CGRect rect = CGRectMake(0, 0, self.size.width, self.size.height);
            addRoundedRectToPath(context, rect, size.width, size.height);
            CGContextClosePath(context);
            CGContextClip(context);
            
            CGContextDrawImage(context, CGRectMake(0, 0, w, h), self.CGImage);
            
            CGImageRef imageMasked = CGBitmapContextCreateImage(context);
            CGContextRelease(context);
            CGColorSpaceRelease(colorSpace);
            
            newImage = [UIImage imageWithCGImage:imageMasked];
            CGImageRelease(imageMasked);
        }
    }
    
    return newImage;
}

@end
