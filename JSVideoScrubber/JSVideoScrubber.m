//
//  JSVideoScrubber.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "UIImage+JSScrubber.h"
#import "JSRenderOperation.h"
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

@interface JSVideoScrubber ()

@property (strong, nonatomic) NSOperationQueue *renderQueue;
@property (strong, nonatomic) AVAsset *asset;
@property (strong, nonatomic) UIImage *imageStrip;

@property (strong, nonatomic) UIImage *scrubberFrame;
@property (strong, nonatomic) UIImage *scrubberBackground;
@property (strong, nonatomic) UIImage *markerMask;
@property (strong, nonatomic) UIImage *marker;
@property (assign, nonatomic) CGFloat markerLocation;

@property (assign, nonatomic) BOOL blockOffsetUpdates;

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
    
    UIEdgeInsets uniformInsets = UIEdgeInsetsMake(kJSFrameInset, kJSFrameInset, kJSFrameInset, kJSFrameInset);
    
    self.scrubberBackground = [[UIImage imageNamed:@"scrubber_inner"] resizableImageWithCapInsets:uniformInsets];
    self.scrubberFrame = [[UIImage imageNamed:@"scrubber_outer"] resizableImageWithCapInsets:uniformInsets];
    self.markerMask = [[[UIImage imageNamed:@"scrubber_mask"] flipImageVertically] resizableImageWithCapInsets:uniformInsets];
    self.marker = [UIImage imageNamed:@"slider"];

    self.markerLocation = js_marker_start;
    self.blockOffsetUpdates = NO;
    self.imageStrip = nil;
    
    self.layer.opacity = 0.0f;
        
    [self.renderQueue setSuspended:NO];
}

#pragma mark - UIView

- (void) drawRect:(CGRect) rect
{
    [self.scrubberBackground drawInRect:rect];
    [self.scrubberFrame drawInRect:rect];

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    if (self.asset && self.imageStrip) {
        CGImageRef masked = self.imageStrip.CGImage;

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

- (void) layoutSubviews
{
    if (!self.asset) {
        return;
    }
    
    [UIView animateWithDuration:0.25f animations:^{
        self.layer.opacity = 0.0f;
    }
    completion:^(BOOL finished) {
        self.imageStrip = nil;
        
        [self setupControlWithAVAsset:self.asset];
        [self setNeedsDisplay];
    }];
}

#pragma mark - UIControl

- (BOOL) beginTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    self.blockOffsetUpdates = YES;
    
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

- (void) cancelTrackingWithEvent:(UIEvent *)event
{
    self.blockOffsetUpdates = NO;
    [super cancelTrackingWithEvent:event];
}

- (void) endTrackingWithTouch:(UITouch *)touch withEvent:(UIEvent *)event
{
    self.blockOffsetUpdates = NO;
    [super endTrackingWithTouch:touch withEvent:event];
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
    if (self.blockOffsetUpdates) {
        return;
    }
    
    CGFloat x = (offset / CMTimeGetSeconds(self.duration)) * (self.frame.size.width - (2 * kJSMarkerXStop));
    [self updateMarkerToPoint:CGPointMake(x + js_marker_start, 0.0f)];
    
    _offset = offset;
}

- (void) setupControlWithAVAsset:(AVAsset *) asset
{
    NSAssert(self.frame.size.height >= 90.0f, @"Minimum height supported by the control is 90 px");
    
    self.asset = asset;
    self.duration = asset.duration;
    
    [self queueRenderOperationForAsset:self.asset indexedAt:nil];
}

- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    NSAssert(self.frame.size.height >= 90.0f, @"Minimum height supported by the control is 90 px");
    
    self.asset = asset;
    self.duration = asset.duration;
    
    [self queueRenderOperationForAsset:self.asset indexedAt:requestedTimes];
}

- (void) reset
{
    [self.renderQueue cancelAllOperations];
    
    [UIView animateWithDuration:0.25f animations:^{
        self.layer.opacity = 0.0f;
    }
    
    completion:^(BOOL finished) {
        self.asset = nil;
        self.imageStrip = nil;
         
        self.duration = CMTimeMakeWithSeconds(0.0, 1);
        self.offset = 0.0f;
         
        self.markerLocation = js_marker_start;
     }];
}

#pragma mark - Internal

- (void) queueRenderOperationForAsset:(AVAsset *)asset indexedAt:(NSArray *)indexes
{
    JSRenderOperation *op = nil;

    if (indexes) {
        op = [[JSRenderOperation alloc] initWithAsset:asset indexAt:indexes targetFrame:self.frame];
    } else {
        op = [[JSRenderOperation alloc] initWithAsset:asset targetFrame:self.frame];
    }
    
    op.renderCompletionBlock = ^(UIImage *strip, NSError *error) {
        if (error) {
            //todo: log error?
        }
        
        self.imageStrip = strip;
        [self setNeedsDisplay];
        
        [UIView animateWithDuration:0.25f animations:^{
            self.layer.opacity = 1.0f;
        }];
    };
    
    [self.renderQueue cancelAllOperations];
    [self.renderQueue addOperation:op];
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

@end
