//
//  JSVideoScrubber.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "JSVideoScrubber.h"

@interface JSVideoScrubber ()

@property (strong) AVAssetImageGenerator *assetImageGenerator;
@property (strong) NSMutableArray *actualOffsets;
@property (strong) NSMutableDictionary *imageStrip;
@property (assign) CMTime duration;
@property (assign) size_t sourceWidth;
@property (assign) size_t sourceHeight;

@end

@implementation JSVideoScrubber

#pragma mark - Memory

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.actualOffsets = [NSMutableArray array];
        self.imageStrip = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        self.actualOffsets = [NSMutableArray array];
        self.imageStrip = [NSMutableDictionary dictionary];
    }
    
    return self;
}

#pragma mark - UIView

- (void) drawRect:(CGRect) rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    for (int offset = 0; offset < [self.actualOffsets count]; offset++) {
        NSNumber *time = [self.actualOffsets objectAtIndex:offset];
        CGImageRef image = (__bridge CGImageRef)([self.imageStrip objectForKey:time]);
        
        size_t height = CGImageGetHeight(image);
        size_t width = CGImageGetWidth(image);
        
        CGRect forOffset = CGRectMake((rect.origin.x + (offset * width)), rect.origin.y, width, height);
        CGContextDrawImage(context, forOffset, image);
    }
}

#pragma mark - Interface

- (void) setupControlWithAVAsset:(AVAsset *) asset
{
    self.assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef image = [self.assetImageGenerator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 1) actualTime:&actualTime error:&error];
    
    if (error) {
        NSLog(@"Error copying reference image.");
    }
    
    self.sourceWidth = CGImageGetWidth(image);
    self.sourceHeight = CGImageGetHeight(image);
    
    [self createStrip:asset indexedAt:[self generateOffsets:asset]];
}

- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    self.assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    [self createStrip:asset indexedAt:requestedTimes];
}

#pragma mark - Internal

- (void) createStrip:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    self.duration = asset.duration;
    
    for (NSNumber *number in requestedTimes)
    {
        double offset = [number doubleValue];
        
        if (offset < 0 || offset > CMTimeGetSeconds(asset.duration)) {
            continue;
        }
        
        [self updateImageStrip:CMTimeMakeWithSeconds(offset, 1)];
    }
    
    //ensure keys are sorted
    [self.actualOffsets sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        double first = [obj1 doubleValue];
        double second = [obj2 doubleValue];
        
        if (first > second) {
            return NSOrderedDescending;
        }
        
        if (first < second) {
            return NSOrderedAscending;
        }
        
        return NSOrderedSame;
    }];
    
    [self setNeedsDisplay];
}

- (NSArray *) generateOffsets:(AVAsset *) asset
{
    CGFloat aspect = (self.sourceWidth * 1.0f) / self.sourceHeight;
    
    CGFloat idealInterval = self.frame.size.height * aspect;
    CGFloat intervals = self.frame.size.width / idealInterval;
    
    double duration = CMTimeGetSeconds(asset.duration);
    double offset = duration / intervals;
    
    NSMutableArray *offsets = [NSMutableArray array];

    double time = 0.0f;
    
    while (time < duration) {
        [offsets addObject:[NSNumber numberWithDouble:time]];
        time += offset;
    }
    
    return offsets;
}

- (void) updateImageStrip:(CMTime) offset
{
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef source = [self.assetImageGenerator copyCGImageAtTime:offset actualTime:&actualTime error:&error];
    CGImageRef scaled = [self createScaleImage:source];
    
    if (error) {
        NSLog(@"Error copying image at index %f: %@", CMTimeGetSeconds(offset), [error localizedDescription]);
    }
    
    NSNumber *key = [NSNumber numberWithDouble:CMTimeGetSeconds(actualTime)];

    [self.imageStrip setObject:CFBridgingRelease(scaled) forKey:key];  //transfer img ownership to arc
    [self.actualOffsets addObject:key];
}

- (CGImageRef) createScaleImage:(CGImageRef) source
{
    CGFloat aspect = (self.sourceWidth * 1.0f) / self.sourceHeight;
    
    size_t height = (size_t)self.frame.size.height;
    size_t width = (size_t)(self.frame.size.height * aspect);

    CGColorSpaceRef colorspace = CGImageGetColorSpace(source);
    
    CGContextRef context = CGBitmapContextCreate(NULL,
                                                 width,
                                                 height,
                                                 CGImageGetBitsPerComponent(source),
                                                 (CGImageGetBytesPerRow(source) / CGImageGetWidth(source) * width),
                                                 colorspace,
                                                 CGImageGetAlphaInfo(source));
    if(context == NULL) {
        return NULL;
    }
    
    CGContextDrawImage(context, CGContextGetClipBoundingBox(context), source);
    return CGBitmapContextCreateImage(context);
}

@end
