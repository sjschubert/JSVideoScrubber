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

@property (strong, nonatomic) AVAssetImageGenerator *assetImageGenerator;
@property (strong, nonatomic) NSMutableArray *actualOffsets;
@property (strong, nonatomic) NSMutableDictionary *imageStrip;
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
    self.imageStrip = [NSMutableDictionary dictionary];

    UIEdgeInsets uniformInsets = UIEdgeInsetsMake(kJSFrameInset, kJSFrameInset, kJSFrameInset, kJSFrameInset);
    
    self.scrubberBackground = [[UIImage imageNamed:@"scrubber_inner"] resizableImageWithCapInsets:uniformInsets];
    self.scrubberFrame = [[UIImage imageNamed:@"scrubber_outer"] resizableImageWithCapInsets:uniformInsets];
    self.markerMask = [[[UIImage imageNamed:@"scrubber_mask"] flipImageVertically] resizableImageWithCapInsets:uniformInsets];
    self.marker = [UIImage imageNamed:@"slider"];

    self.markerLocation = kJSMarkerXStop - js_marker_center;
}

#pragma mark - UIView

- (void) drawRect:(CGRect) rect
{
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    [self.scrubberBackground drawInRect:rect];
    [self.scrubberFrame drawInRect:rect];
    
    CGRect stripFrame = [self frameForStrip:self.imageStrip];

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef stripCtx = CGBitmapContextCreate(NULL, stripFrame.size.width,
                                                        stripFrame.size.height,
                                                        8,
                                                        (4 * stripFrame.size.width),
                                                        colorSpace,
                                                        kCGImageAlphaPremultipliedFirst);

    CGFloat padding = 0.0f;
    
    //render image strip to context
    for (int idx = 0; idx < [self.actualOffsets count]; idx++) {
        NSNumber *time = [self.actualOffsets objectAtIndex:idx];
        CGImageRef image = (__bridge CGImageRef)([self.imageStrip objectForKey:time]);
        
        size_t height = CGImageGetHeight(image);
        size_t width = CGImageGetWidth(image);
        
        CGFloat x = (idx * width) + padding;
        CGRect forOffset = CGRectMake(x, 0, width, height);
        
        CGContextDrawImage(stripCtx, forOffset, image);
        padding += kJSImageDivider;
    }
    
    CGImageRef strip = CGBitmapContextCreateImage(stripCtx);
    
    CGImageRef masked = [[UIImage imageWithCGImage:strip] maskWithCornerSize:CGSizeMake(20.0f, 20.0f)].CGImage;

    size_t masked_h = CGImageGetHeight(strip);
    size_t masked_w = CGImageGetWidth(strip);
    
    CGFloat x = rect.origin.x + kJSSideFrame + kJSImageBorder;
    CGFloat y = rect.origin.y + kJSMarkerYOffset + kJSImageBorder + 0.5f;
    CGContextDrawImage(context, CGRectMake(x, y, masked_w, masked_h), masked);

    CGContextRelease(stripCtx);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(strip);

    CGPoint offset = CGPointMake((rect.origin.x + self.markerLocation), rect.origin.y + 15);
    UIImage *offsetMarker = [[UIImage drawImageIntoRect:rect.size offset:offset image:self.marker] applyMask:self.markerMask];

    CGContextDrawImage(context, rect, offsetMarker.CGImage);
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
    self.assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    self.assetImageGenerator.appliesPreferredTrackTransform = YES;
    
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef image = [self.assetImageGenerator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 1) actualTime:&actualTime error:&error];
    
    if (error) {
        NSLog(@"Error extracting reference image from asset: %@", [error localizedDescription]);
        return;
    }
    
    //AVAssetTrack* videoTrack = [[self.assetImageGenerator.asset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0];
    //CGAffineTransform txf = [videoTrack preferredTransform];
    //NSLog(@"txf.a = %f txf.b = %f txf.c = %f txf.d = %f txf.tx = %f txf.ty = %f", txf.a, txf.b, txf.c, txf.d, txf.tx, txf.ty);
    
    self.sourceWidth = CGImageGetWidth(image);
    self.sourceHeight = CGImageGetHeight(image);
    
    [self createStrip:asset indexedAt:[self generateOffsets:asset]];
}

- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    self.assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    [self createStrip:asset indexedAt:requestedTimes];
}

- (void) reset
{
    self.assetImageGenerator = nil;
    
    [self.actualOffsets removeAllObjects];
    [self.imageStrip removeAllObjects];
    
    self.markerLocation = kJSMarkerXStop - js_marker_center;
    [self setNeedsDisplay];
}

#pragma mark - Internal

- (void) createStrip:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    self.duration = asset.duration;
    self.markerLocation = kJSMarkerXStop - js_marker_center;
    
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

- (CGRect) frameForStrip:(NSDictionary *)images
{
    if ([images count] <= 0) {
        return CGRectMake(0.0f, 0.0f, 0.0f, 0.0f);
    }
    
    NSNumber *time = [self.actualOffsets objectAtIndex:0];
    CGImageRef image = (__bridge CGImageRef)([self.imageStrip objectForKey:time]);
        
    return CGRectMake(0.0f, 0.0f, self.frame.size.width - (2 * (kJSSideFrame + kJSImageBorder)) - kJSImageDivider, CGImageGetHeight(image));
}

@end
