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
#define kJSMarkerXStop 29.0f
#define kJSMarkerYOffset 15.0f
#define kJSSideFrame 8.0f
#define kJSBottomFrame 22.0f

#define kJSImageBorder 4.0f
#define kJSImageDivider 2.0f

#define js_marker_center (self.marker.size.width / 2)
#define js_scaled_img_height (self.frame.size.height - (kJSMarkerYOffset + kJSBottomFrame + (2 * kJSImageBorder)))


@interface JSVideoScrubber ()

@property(assign, nonatomic) CGSize currentSize;

@property (strong, nonatomic) AVAsset *asset;
@property (strong, nonatomic) AVAssetImageGenerator *assetImageGenerator;
@property (strong, nonatomic) NSMutableArray *actualOffsets;
@property (strong, nonatomic) NSMutableDictionary *images;
@property (assign, nonatomic) size_t sourceWidth;
@property (assign, nonatomic) size_t sourceHeight;

@property (strong, nonatomic) UIImage *scrubberFrame;
@property (strong, nonatomic) UIImage *scrubberBackground;
@property (strong, nonatomic) UIImage *markerMask;
@property (strong, nonatomic) UIImage *marker;
@property (assign, nonatomic) CGFloat markerLocation;
@property (assign, nonatomic) CGFloat touchOffset;

@end

@implementation JSVideoScrubber

#pragma mark - Initialization

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
    self.images = [NSMutableDictionary dictionary];

    UIEdgeInsets uniformInsets = UIEdgeInsetsMake(kJSFrameInset, kJSFrameInset, kJSFrameInset, kJSFrameInset);
    
    self.scrubberBackground = [[UIImage imageNamed:@"scrubber_inner"] resizableImageWithCapInsets:uniformInsets];
    self.scrubberFrame = [[UIImage imageNamed:@"scrubber_outer"] resizableImageWithCapInsets:uniformInsets];
    self.markerMask = [[[UIImage imageNamed:@"scrubber_mask"] flipImageVertically] resizableImageWithCapInsets:uniformInsets];
    self.marker = [UIImage imageNamed:@"slider"];

    self.markerLocation = kJSMarkerXStop - js_marker_center;
    self.currentSize = self.frame.size;
}

#pragma mark - UIView

- (void) drawRect:(CGRect) rect
{
    [self.scrubberBackground drawInRect:rect];
    [self.scrubberFrame drawInRect:rect];

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (self.asset) {
        CGImageRef masked = [self drawStrip].CGImage;

        size_t masked_h = CGImageGetHeight(masked);
        size_t masked_w = CGImageGetWidth(masked);
        
        CGFloat x = rect.origin.x + kJSSideFrame + kJSImageBorder;
        CGFloat y = rect.origin.y + kJSMarkerYOffset + kJSImageBorder + 0.5f;
        
        CGContextDrawImage(context, CGRectMake(x, y, masked_w, masked_h), masked);
    }

    CGPoint offset = CGPointMake((rect.origin.x + self.markerLocation), rect.origin.y + 15);
    UIImage *offsetMarker = [[UIImage drawImageIntoRect:rect.size offset:offset image:self.marker] applyMask:self.markerMask];

    CGContextDrawImage(context, rect, offsetMarker.CGImage);
}

- (UIImage *) drawStrip
{
    CGRect stripFrame = [self frameForImageStrip:self.images];
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef stripCtx = CGBitmapContextCreate(NULL, stripFrame.size.width,
                                                  stripFrame.size.height,
                                                  8,
                                                  (4 * stripFrame.size.width),
                                                  colorSpace,
                                                  kCGImageAlphaPremultipliedFirst);
    CGFloat padding = 0.0f;
    
    for (int idx = 0; idx < [self.actualOffsets count]; idx++) {
        NSNumber *time = [self.actualOffsets objectAtIndex:idx];
        CGImageRef image = (__bridge CGImageRef)([self.images objectForKey:time]);
        
        size_t height = CGImageGetHeight(image);
        size_t width = CGImageGetWidth(image);
        
        CGFloat x = (idx * width) + padding;
        CGRect forOffset = CGRectMake(x, 0, width, height);
        
        CGContextDrawImage(stripCtx, forOffset, image);
        padding += kJSImageDivider;
    }
    
    CGImageRef raw = CGBitmapContextCreateImage(stripCtx);
    UIImage *strip = [[UIImage imageWithCGImage:raw] maskWithCornerSize:CGSizeMake(20.0f, 20.0f)];
    
    CGContextRelease(stripCtx);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(raw);

    return strip;
}

- (void) layoutSubviews
{
    //reset extracted images
    [self.actualOffsets removeAllObjects];
    [self.images removeAllObjects];
    
    //regenerate thumbnails
    [self setupControlWithAVAsset:self.asset];
    [self setNeedsDisplay];
}

#pragma mark - UIControl

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:self];
    
    if (![self markerHitTest:touchPoint]) {
        return NO;
    }
    
    self.touchOffset = touchPoint.x - self.markerLocation;
    return YES;
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint touchPoint = [touch locationInView:self];
    
    if ((touchPoint.x - self.touchOffset) < (kJSMarkerXStop - js_marker_center)) {
        self.markerLocation = kJSMarkerXStop - (self.marker.size.width / 2);
    } else if ((touchPoint.x - self.touchOffset) > (self.frame.size.width - (kJSMarkerXStop + js_marker_center))) {
        self.markerLocation = self.frame.size.width - (kJSMarkerXStop + js_marker_center);
    } else {
        self.markerLocation = touchPoint.x - self.touchOffset;
    }
    
    self.offset = [self offsetForMarker];
    
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
    NSAssert(self.frame.size.height >= 90.0f, @"Minimum height supported by the control is 90 px");
    
    self.asset = asset;
    self.assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    self.assetImageGenerator.appliesPreferredTrackTransform = YES;
    
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef image = [self.assetImageGenerator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 1) actualTime:&actualTime error:&error];
    
    if (error) {
        NSLog(@"Error extracting reference image from asset: %@", [error localizedDescription]);
        return;
    }
        
    self.sourceWidth = CGImageGetWidth(image);
    self.sourceHeight = CGImageGetHeight(image);
    
    CGImageRelease(image);
    
    [self extractFromAsset:asset atIndexes:[self generateOffsets:asset]];
}

- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    self.assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    [self extractFromAsset:asset atIndexes:requestedTimes];
}

- (void) reset
{
    self.asset = nil;
    self.assetImageGenerator = nil;
    
    [self.actualOffsets removeAllObjects];
    [self.images removeAllObjects];
    
    self.duration = CMTimeMakeWithSeconds(0.0, 1);
    self.offset = 0.0f;
    
    self.markerLocation = kJSMarkerXStop - js_marker_center;
    [self setNeedsDisplay];
}

#pragma mark - Internal

- (void) extractFromAsset:(AVAsset *) asset atIndexes:(NSArray *) requestedTimes
{
    self.duration = asset.duration;
    self.markerLocation = kJSMarkerXStop - js_marker_center;
    
    for (NSNumber *number in requestedTimes)
    {
        double offset = [number doubleValue];
        
        if (offset < 0 || offset > CMTimeGetSeconds(asset.duration)) {
            continue;
        }
        
        [self extractImageAt:CMTimeMakeWithSeconds(offset, 1)];
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
    
    CGFloat idealInterval = js_scaled_img_height * aspect;
    CGFloat intervals = (self.frame.size.width) / idealInterval;
    
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

- (void) extractImageAt:(CMTime) offset
{
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef source = [self.assetImageGenerator copyCGImageAtTime:offset actualTime:&actualTime error:&error];
    CGImageRef scaled = [self createScaledImage:source];
    
    if (error) {
        NSLog(@"Error copying image at index %f: %@", CMTimeGetSeconds(offset), [error localizedDescription]);
    }
    
    NSNumber *key = [NSNumber numberWithDouble:CMTimeGetSeconds(actualTime)];

    [self.images setObject:CFBridgingRelease(scaled) forKey:key];  //transfer img ownership to arc
    [self.actualOffsets addObject:key];
    
    CFRelease(source);
}

- (CGImageRef) createScaledImage:(CGImageRef) source
{
    CGFloat aspect = (self.sourceWidth * 1.0f) / self.sourceHeight;
    
    size_t height = (size_t)js_scaled_img_height;
    size_t width = (size_t)(height * aspect);

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
    CGFloat ratio = (((self.markerLocation + js_marker_center) - kJSMarkerXStop) / (self.frame.size.width - (2 * kJSMarkerXStop)));
    return (ratio * CMTimeGetSeconds(self.duration));
}

- (BOOL) markerHitTest:(CGPoint) point
{
    if (point.x < self.markerLocation || point.x > (self.markerLocation + self.marker.size.width)) { //x test
        return NO;
    }

    if (point.y < kJSMarkerYOffset || point.y > (kJSMarkerYOffset + self.marker.size.height)) { //y test
        return NO;
    }

    return YES;
}

- (CGRect) frameForImageStrip:(NSDictionary *)images
{
    if ([images count] <= 0) {
        return CGRectMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    NSNumber *time = [self.actualOffsets objectAtIndex:0];
    CGImageRef image = (__bridge CGImageRef)([self.images objectForKey:time]);
        
    return CGRectMake(0.0f, 0.0f, self.frame.size.width - (2 * (kJSSideFrame + kJSImageBorder)) - kJSImageDivider, CGImageGetHeight(image));
}

- (BOOL) hasChangedSize:(CGSize)size
{
    return (self.currentSize.width != size.width) || (self.currentSize.height != size.height);
}

@end
