//
//  JSVideoScrubber.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIImage+JSScrubber.h"
#import "JSVideoScrubber.h"

#define kJSFrameInset 44.0f
#define kJSMarkerYOffset 15.0f
#define kJSMarkerXStop 29.0f
#define kJSMarkerCenter (self.marker.size.width / 2)

@interface JSVideoScrubber ()

@property (strong) AVAssetImageGenerator *assetImageGenerator;
@property (strong) NSMutableArray *actualOffsets;
@property (strong) NSMutableDictionary *imageStrip;
@property (assign) size_t sourceWidth;
@property (assign) size_t sourceHeight;

@property (strong) UIImage *scrubberFrame;
@property (strong) UIImage *scrubberBackground;
@property (strong) UIImage *markerMask;
@property (strong) UIImage *marker;
@property (assign) CGFloat markerLocation;
@property (assign) CGFloat touchOffset;

@end

@implementation JSVideoScrubber

#pragma mark - Memory

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        [self initScrubber];
    }
    
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    
    if (self) {
        [self initScrubber];
    }
    
    return self;
}

- (void) initScrubber
{
    self.actualOffsets = [NSMutableArray array];
    self.imageStrip = [NSMutableDictionary dictionary];

    UIEdgeInsets uniformInsets = UIEdgeInsetsMake(kJSFrameInset, kJSFrameInset, kJSFrameInset, kJSFrameInset);
    
    self.scrubberBackground = [[UIImage imageNamed:@"scrubber_inner"] resizableImageWithCapInsets:uniformInsets];
    self.scrubberFrame = [[UIImage imageNamed:@"scrubber_outer"] resizableImageWithCapInsets:uniformInsets];
    self.markerMask = [[[UIImage imageNamed:@"scrubber_mask"] flipImageVertically] resizableImageWithCapInsets:uniformInsets];
    self.marker = [UIImage imageNamed:@"slider"]; //resizableImageWithCapInsets:UIEdgeInsetsMake(kJSFrameInset, 0, kJSFrameInset, 0)];

    self.markerLocation = kJSMarkerXStop - kJSMarkerCenter;
}

#pragma mark - UIView

- (void) drawRect:(CGRect) rect
{
    [self.scrubberBackground drawInRect:rect];
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [self.scrubberFrame drawInRect:rect];

//    for (int offset = 0; offset < [self.actualOffsets count]; offset++) {
//        NSNumber *time = [self.actualOffsets objectAtIndex:offset];
//        CGImageRef image = (__bridge CGImageRef)([self.imageStrip objectForKey:time]);
//        
//        size_t height = CGImageGetHeight(image);
//        size_t width = CGImageGetWidth(image);
//        
//        CGRect forOffset = CGRectMake((rect.origin.x + (offset * width)), rect.origin.y, width, height);
//        CGContextDrawImage(context, forOffset, image);
//    }
    
    CGPoint offset = CGPointMake((rect.origin.x + self.markerLocation), rect.origin.y + 15);
    UIImage *offsetMarker = [[UIImage drawImageIntoRect:rect.size offset:offset image:self.marker] applyMask:self.markerMask];
    
    CGContextDrawImage(context, rect, offsetMarker.CGImage);
}

#pragma mark - UIControl

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:self];
    
    NSLog(@"touched: %f", touchPoint.x);
    
    if (![self markerHitTest:touchPoint]) {
        return NO;
    }
    
    self.touchOffset = touchPoint.x - self.markerLocation;
    return YES;
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:self];
    
    if ((touchPoint.x - self.touchOffset) < (kJSMarkerXStop - kJSMarkerCenter)) {
        self.markerLocation = kJSMarkerXStop - (self.marker.size.width / 2);
    } else if ((touchPoint.x - self.touchOffset) > (self.frame.size.width - (kJSMarkerXStop + kJSMarkerCenter))) {
        self.markerLocation = self.frame.size.width - (kJSMarkerXStop + kJSMarkerCenter);
    } else {
        self.markerLocation = touchPoint.x - self.touchOffset;
    }
    
    self.markerOffset = [self offsetForMarker];
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    [self setNeedsDisplay];
    
    return YES;
}

- (void) endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    self.touchOffset = 0.0f;
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
    self.markerLocation = 0.0f;
    
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
    CGImageRef scaled = [self createScaledImage:source];
    
    if (error) {
        NSLog(@"Error copying image at index %f: %@", CMTimeGetSeconds(offset), [error localizedDescription]);
    }
    
    NSNumber *key = [NSNumber numberWithDouble:CMTimeGetSeconds(actualTime)];

    [self.imageStrip setObject:CFBridgingRelease(scaled) forKey:key];  //transfer img ownership to arc
    [self.actualOffsets addObject:key];
    
    CFRelease(source);
}

- (CGImageRef) createScaledImage:(CGImageRef) source
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
    
    //flip image to correct for CG coordinate system
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGContextDrawImage(context, CGContextGetClipBoundingBox(context), source);
    
    CGImageRef scaled = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    
    return scaled;
}

- (CGFloat) offsetForMarker
{
    CGFloat ratio = (self.markerLocation / self.frame.size.width);
    return (ratio * CMTimeGetSeconds(self.duration));
}

- (BOOL) markerHitTest:(CGPoint) point
{    
    //x test
    if (point.x < self.markerLocation || point.x > (self.markerLocation + self.marker.size.width)) {
        return NO;
    }

    //y test
    if (point.y < kJSMarkerYOffset || point.y > (kJSMarkerYOffset + self.marker.size.height)) {
        return NO;
    }

    return YES;
}

@end
