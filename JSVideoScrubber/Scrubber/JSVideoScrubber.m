//
//  JSVideoScrubber.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>

#import "JSAssetDefines.h"
#import "UIImage+JSScrubber.h"
#import "JSRenderOperation.h"
#import "JSVideoScrubber.h"

#define js_marker_center (self.slider.size.width / 2)
#define js_marker_start (self.frame.origin.x + kJSMarkerXStop - js_marker_center)
#define js_marker_stop (self.frame.size.width - (kJSMarkerXStop + js_marker_center))

#define kJSMarkerXStop (js_marker_center + 0.5f)

#define kJSAnimateIn 0.25f

#define kJSTrackingYFudgeFactor 24.0f

@interface JSVideoScrubber ()

@property (strong, nonatomic) NSOperationQueue *renderQueue;
@property (strong, nonatomic) AVAsset *asset;

@property (strong, nonatomic) UIImage *scrubberFrame;
@property (strong, nonatomic) UIImage *slider;
@property (assign, nonatomic) CGFloat markerLocation;
@property (assign, nonatomic) CGFloat touchOffset;
@property (assign, nonatomic) BOOL blockOffsetUpdates;

@property (strong, nonatomic) CALayer *imageStripLayer;
@property (strong, nonatomic) CALayer *markerLayer;

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
    self.renderQueue = [[NSOperationQueue alloc] init];
    self.renderQueue.maxConcurrentOperationCount = 1;
    
    UIEdgeInsets uniformInsets = UIEdgeInsetsMake(0.0f, kJSFrameInset, 0.0f, kJSFrameInset);
    
    self.scrubberFrame = [[UIImage imageNamed:@"scrubber"] resizableImageWithCapInsets:uniformInsets];
    self.slider = [UIImage imageNamed:@"slider"];

    self.markerLocation = js_marker_start;
    self.blockOffsetUpdates = NO;
    
    self.imageStripLayer = [CALayer layer];
    self.markerLayer = [CALayer layer];
    
    [self setupControlLayers];
    
    self.imageStripLayer.actions = @{@"position":[NSNull null], @"bounds":[NSNull null], @"anchorPoint": [NSNull null]};
    self.markerLayer.actions = @{@"position":[NSNull null], @"bounds":[NSNull null], @"anchorPoint": [NSNull null]};
    
    [self.layer addSublayer:self.markerLayer];
    [self.layer insertSublayer:self.imageStripLayer below:self.markerLayer];
    
    self.layer.opacity = 0.0f;
    
    [self.renderQueue setSuspended:NO];
}

#pragma mark - UIView

- (void) drawRect:(CGRect) rect
{
    CGPoint offset = CGPointMake((rect.origin.x + self.markerLocation), rect.origin.y + kJSMarkerYOffset);
    self.markerLayer.position = offset;
    [self setNeedsDisplay];
}

- (void) layoutSubviews
{
    [self setupControlLayers];
    
    if (!self.asset) {
        return;
    }
    
    [UIView animateWithDuration:kJSAnimateIn
        animations:^{
            self.layer.opacity = 0.0f;
        }
        completion:^(BOOL finished) {
            [self setupControlWithAVAsset:self.asset];
            [self setNeedsDisplay];
        }
     ];
}

#pragma mark - UIControl

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    self.blockOffsetUpdates = YES;
    
    CGPoint l = [touch locationInView:self];
    if ([self markerHitTest:l]) {
        self.touchOffset = l.x - self.markerLocation;
    } else {
        self.touchOffset = js_marker_center;
    }
    
    [self updateMarkerToPoint:l];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
    return YES;
}

- (BOOL) continueTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    CGPoint p = [touch locationInView:self];
    
    CGRect trackingFrame = self.bounds;
    trackingFrame.size.height = trackingFrame.size.height + kJSTrackingYFudgeFactor;
    
    if (!CGRectContainsPoint(trackingFrame, p)) {
        return NO;
    }
    
    [self updateMarkerToPoint:p];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
    
    return YES;
}

- (void) cancelTrackingWithEvent:(UIEvent *)event
{
    self.blockOffsetUpdates = NO;
    self.touchOffset = 0.0f;
    
    [super cancelTrackingWithEvent:event];
}

- (void) endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    self.blockOffsetUpdates = NO;
    self.touchOffset = 0.0f;
    
    [super endTrackingWithTouch:touch withEvent:event];
}

- (void) updateMarkerToPoint:(CGPoint) touchPoint
{
    if ((touchPoint.x - self.touchOffset) < js_marker_start) {
        self.markerLocation = js_marker_start;
    } else if (touchPoint.x - self.touchOffset > js_marker_stop) {
        self.markerLocation = js_marker_stop;
    } else {
        self.markerLocation = touchPoint.x - self.touchOffset;
    }
    
    _offset = [self offsetForMarkerLocation];
    [self setNeedsDisplay];
}

#pragma mark - Interface

- (CGFloat) offset
{
    return _offset;
}

- (void) setOffset:(CGFloat)offset
{
    if (self.blockOffsetUpdates) {
        return;
    }
    
    CGFloat x = (offset / CMTimeGetSeconds(self.duration)) * (self.frame.size.width - (2 * kJSMarkerXStop));
    [self updateMarkerToPoint:CGPointMake(x + js_marker_start, 0.0f)];
    
    _offset = offset;
}

- (void) setupControlWithAVAsset:(AVAsset *) asset
{
    self.asset = asset;
    self.duration = asset.duration;
    
    [self queueRenderOperationForAsset:self.asset indexedAt:nil];
}

- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    self.asset = asset;
    self.duration = asset.duration;
    
    [self queueRenderOperationForAsset:self.asset indexedAt:requestedTimes];
}

- (void) reset
{
    [self.renderQueue cancelAllOperations];
    
    [UIView animateWithDuration:0.25f
        animations:^{
            self.layer.opacity = 0.0f;
        }
        completion:^(BOOL finished) {
            self.asset = nil;
            self.duration = CMTimeMakeWithSeconds(0.0, 1);
            self.offset = 0.0f;
         
            self.markerLocation = js_marker_start;
     }];
}

#pragma mark - Internal

- (void) queueRenderOperationForAsset:(AVAsset *)asset indexedAt:(NSArray *)indexes
{
    [self.renderQueue cancelAllOperations];
    
    JSRenderOperation *op = nil;

    if (indexes) {
        op = [[JSRenderOperation alloc] initWithAsset:asset indexAt:indexes targetFrame:self.frame];
    } else {
        op = [[JSRenderOperation alloc] initWithAsset:asset targetFrame:self.frame];
    }

    __weak JSVideoScrubber *ref = self;
    
    op.renderCompletionBlock = ^(UIImage *strip, NSError *error) {
        if (error) {
            NSLog(@"error rendering image strip: %@", error);
        }
        
        UIGraphicsBeginImageContext(ref.imageStripLayer.frame.size);
        CGContextRef context = UIGraphicsGetCurrentContext();
        
        [ref.scrubberFrame drawInRect:ref.imageStripLayer.frame];
        
        CGImageRef masked = strip.CGImage;
        
        size_t masked_h = CGImageGetHeight(masked);
        size_t masked_w = CGImageGetWidth(masked);
        
        CGFloat x = ref.imageStripLayer.frame.origin.x + kJSImageBorder + kJSImageDivider;
        CGFloat y = ref.imageStripLayer.frame.origin.y + kJSImageBorder + 0.5f;
        
        CGContextDrawImage(context, CGRectMake(x, y, masked_w, masked_h), masked);
        
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        ref.imageStripLayer.contents = (__bridge id)img.CGImage;
        
        UIGraphicsEndImageContext();
        
        ref.markerLayer.contents = (__bridge id)ref.slider.CGImage;
        ref.markerLocation = [ref markerLocationForCurrentOffset];
        
        [ref setNeedsDisplay];
        
        [UIView animateWithDuration:kJSAnimateIn animations:^{
            ref.layer.opacity = 1.0f;
        }];
    };

    [self.renderQueue addOperation:op];
}

- (CGFloat) offsetForMarkerLocation
{
    CGFloat ratio = (((self.markerLocation + js_marker_center) - kJSMarkerXStop) / (self.frame.size.width - (2 * kJSMarkerXStop)));
    return (ratio * CMTimeGetSeconds(self.duration));
}

- (CGFloat) markerLocationForCurrentOffset
{
    CGFloat ratio = self.offset / CMTimeGetSeconds(self.duration);
    CGFloat location = ratio * (js_marker_stop - js_marker_start);

    if (location < js_marker_start) {
        return js_marker_start;
    }
    
    if (location > js_marker_stop) {
        return js_marker_stop;
    }
    
    return location;
}

- (BOOL) markerHitTest:(CGPoint) point
{
    if (point.x < self.markerLocation || point.x > (self.markerLocation + self.slider.size.width)) { //x test
        return NO;
    }

    if (point.y < kJSMarkerYOffset || point.y > (kJSMarkerYOffset + self.slider.size.height)) { //y test
        return NO;
    }

    return YES;
}

- (void) setupControlLayers
{
    self.imageStripLayer.bounds = self.bounds;
    self.markerLayer.bounds = CGRectMake(0, 0, self.slider.size.width, self.slider.size.height);
    
    self.imageStripLayer.anchorPoint = CGPointZero;
    self.markerLayer.anchorPoint = CGPointZero;

}

@end
