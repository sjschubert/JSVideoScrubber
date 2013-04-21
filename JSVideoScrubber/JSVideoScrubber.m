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

#define kCornerRadius 20.0f

#define js_marker_center (self.marker.size.width / 2)
#define js_marker_start (self.frame.origin.x + kJSMarkerXStop - js_marker_center)
#define js_marker_stop (self.frame.size.width - (kJSMarkerXStop + js_marker_center))
#define js_scaled_img_height (self.frame.size.height - (kJSMarkerYOffset + kJSBottomFrame + (2 * kJSImageBorder)))

@interface JSVideoScrubber ()

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

@end

@implementation JSVideoScrubber

@synthesize offset = _offset;

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

    self.markerLocation = js_marker_start;
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
    
    CGContextTranslateCTM(stripCtx, 0, stripFrame.size.height);
    CGContextScaleCTM(stripCtx, 1.0, -1.0);
    
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
    UIImage *strip = [[UIImage imageWithCGImage:raw] maskWithCornerSize:CGSizeMake(kCornerRadius, kCornerRadius)];
    
    CGContextRelease(stripCtx);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(raw);

    return strip;
}

- (void) layoutSubviews
{
    if (!self.asset) {
        return;
    }
    
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
    [self updateMarkerToPoint:[touch locationInView:self]];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    return YES;
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    [self updateMarkerToPoint:[touch locationInView:self]];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    return YES;
}

- (void) updateMarkerToPoint:(CGPoint) touchPoint
{
    if (touchPoint.x < js_marker_start) {
        self.markerLocation = js_marker_start;
    } else if (touchPoint.x > js_marker_stop) {
        self.markerLocation = js_marker_stop;
    } else {
        self.markerLocation = touchPoint.x;
    }

    _offset = [self offsetForMarker];
    [self setNeedsDisplay];
}

#pragma mark - Interface

- (CGFloat) offset
{
    return _offset;
}

- (void) setOffset:(CGFloat)offset
{
    CGFloat x = (offset / CMTimeGetSeconds(self.duration)) * (self.frame.size.width - (2 * kJSMarkerXStop));
    [self updateMarkerToPoint:CGPointMake(x + js_marker_start, 0.0f)];
    
    _offset = offset;
}

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
    
    CGFloat aspect = (self.sourceWidth * 1.0f) / self.sourceHeight;
    
    size_t height = (size_t)js_scaled_img_height;
    size_t width = (size_t)(height * aspect);
    self.assetImageGenerator.maximumSize = CGSizeMake(width, height);
    
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
    
    self.markerLocation = js_marker_start;
    [self setNeedsDisplay];
}

#pragma mark - Internal

- (void) extractFromAsset:(AVAsset *) asset atIndexes:(NSArray *) requestedTimes
{
    self.duration = asset.duration;
    self.markerLocation = js_marker_start;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{        
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
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsDisplay];
        });
    });
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
    [NSThread isMainThread] ? NSLog(@"maint thread") : NSLog(@"backgrnd thread");
    
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef source = [self.assetImageGenerator copyCGImageAtTime:offset actualTime:&actualTime error:&error];
    
    if (error) {
        NSLog(@"Error copying image at index %f: %@", CMTimeGetSeconds(offset), [error localizedDescription]);
    }
    
    NSNumber *key = [NSNumber numberWithDouble:CMTimeGetSeconds(actualTime)];

    [self.images setObject:CFBridgingRelease(source) forKey:key];  //transfer img ownership to arc
    [self.actualOffsets addObject:key];
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

@end
