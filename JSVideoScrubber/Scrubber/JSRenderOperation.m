//
//  JSRenderOperation.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 5/11/13.
//  Copyright (c) 2013 jaminschubert. All rights reserved.
//

#import "JSAssetDefines.h"
#import "UIImage+JSScrubber.h"
#import "JSRenderOperation.h"


#define js_marker_center (self.marker.size.width / 2)
#define js_marker_start (self.frame.origin.x + kJSMarkerXStop - js_marker_center)
#define js_marker_stop (self.frame.size.width - (kJSMarkerXStop + js_marker_center))
#define js_scaled_img_height (self.frame.size.height - (kJSMarkerYOffset + (2 * kJSImageBorder)))

@interface NSDictionary (JSSorting)

- (NSArray *) sortedKeys;

@end

@implementation NSDictionary (JSSorting)

- (NSArray *) sortedKeys
{
    return [[self allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
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
}

@end

@interface JSRenderOperation()

@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) AVAssetImageGenerator *generator;

@property (nonatomic, assign) CGRect frame;
@property (strong, nonatomic) NSArray *offsets;

@end

@implementation JSRenderOperation

#pragma mark - Memory mgmt

- (id) initWithAsset:(AVAsset *)asset targetFrame:(CGRect) frame
{
    self = [super init];
    
    if (self) {
        self.asset = asset;
        self.frame = frame;
        
        self.offsets = [NSArray array];

        self.generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        self.generator.appliesPreferredTrackTransform = YES;
    }
    
    return self;
}

- (id) initWithAsset:(AVAsset *)asset indexAt:(NSArray *)indexes targetFrame:(CGRect) frame
{
    self = [super init];
    
    if (self) {
        self.asset = asset;
        self.frame = frame;
        
        self.offsets = indexes;
        
        self.generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
        self.generator.appliesPreferredTrackTransform = YES;
    }
    
    return self;
}

#pragma mark - NSOperation overrides

- (void) main
{
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef image = [self.generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 1) actualTime:&actualTime error:&error];
    
    if (self.isCancelled) {
        return;
    }
    
    if (error) {
        NSLog(@"Error extracting reference image from asset: %@", [error localizedDescription]);
        return;
    }
    
    size_t sourceWidth = CGImageGetWidth(image);
    size_t sourceHeight = CGImageGetHeight(image);
    
    CGFloat aspect = (sourceWidth * 1.0f) / sourceHeight;
    
    size_t height = (size_t)js_scaled_img_height;
    size_t width = (size_t)(height * aspect);
    
    self.generator.maximumSize = CGSizeMake(width, height);
    
    CGImageRelease(image);

    if (self.isCancelled) {
        return;
    }

    NSDictionary *images = nil;
    
    if ([self.offsets count] == 0) {
        images = [self extractFromAssetAt:[self generateOffsets:self.asset targetFrame:self.frame width:width] error:&error];
    } else {
        images = [self extractFromAssetAt:self.offsets error:&error];
    }
    
    if (self.isCancelled) {
        return;
    }
    
    UIImage *strip = nil;
    
    if (images) {
        strip = [self drawStripWithImages:images targetFrame:self.frame imgWidth:width imgHeight:height];
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.renderCompletionBlock(strip, error);
    });
}

#pragma mark - Support

- (NSArray *) generateOffsets:(AVAsset *) asset targetFrame:(CGRect) frame width:(size_t) width
{
    CGFloat intervals = (frame.size.width) / width;
    
    double duration = CMTimeGetSeconds(asset.duration);
    double offset = duration / intervals;
    
    NSMutableArray *indexes = [NSMutableArray array];
    
    double time = 0.0f;
    
    while (time < duration) {
        [indexes addObject:[NSNumber numberWithDouble:time]];
        time += offset;
    }
    
    return indexes;
}

- (NSDictionary *) extractFromAssetAt:(NSArray *)indexes error:(NSError **)error
{
    NSMutableDictionary *images = [NSMutableDictionary dictionaryWithCapacity:[indexes count]];
    
    CMTime actualTime;
    
    for (NSNumber *number in indexes) {
        
        if (self.isCancelled) {
            return nil;
        }
        
        double offset = [number doubleValue];
        
        if (offset < 0 || offset > CMTimeGetSeconds(self.asset.duration)) {
            continue;
        }
        
        CMTime t = CMTimeMakeWithSeconds(offset, 100000);
        CGImageRef source = [self.generator copyCGImageAtTime:t actualTime:&actualTime error:error];
        
        if (!source) {
            NSLog(@"Error copying image at index %f: %@", CMTimeGetSeconds(actualTime), [*error localizedDescription]);
            return nil;
        }
        
        [images setObject:CFBridgingRelease(source) forKey:number];  //transfer img ownership to arc
    }
    
    return images;
}

- (UIImage *) drawStripWithImages:(NSDictionary *)images targetFrame:(CGRect) frame imgWidth:(size_t) width imgHeight:(size_t) height
{
    CGFloat border = (2 * kJSImageBorder) + (2 * kJSImageDivider);
    CGRect stripFrame = CGRectMake(0.0f, 0.0f,(frame.size.width - border), height);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef stripCtx = CGBitmapContextCreate(NULL, stripFrame.size.width,
                                                  stripFrame.size.height,
                                                  8,
                                                  (4 * stripFrame.size.width),
                                                  colorSpace,
                                                  kCGImageAlphaPremultipliedFirst);
    
    CGContextTranslateCTM(stripCtx, 0, stripFrame.size.height);
    CGContextScaleCTM(stripCtx, 1.0, -1.0);
    
    NSArray *times = [images sortedKeys];
    CGFloat padding = 0.0f;
    
    for (int idx = 0; idx < [times count]; idx++) {
        if (self.isCancelled) {
            CGContextRelease(stripCtx);
            CGColorSpaceRelease(colorSpace);
            return nil;
        }
        
        NSNumber *time = [times objectAtIndex:idx];
        CGImageRef image = (__bridge CGImageRef)([images objectForKey:time]);
        
        size_t height = CGImageGetHeight(image);
        size_t width = CGImageGetWidth(image);
        
        CGFloat x = (idx * width) + padding;
        CGRect forOffset = CGRectMake(x, 0, width, height);
        
        CGContextDrawImage(stripCtx, forOffset, image);
        padding += kJSImageDivider;
    }
    
    CGImageRef raw = CGBitmapContextCreateImage(stripCtx);
    UIImage *strip = [UIImage imageWithCGImage:raw];
    
    CGContextRelease(stripCtx);
    CGColorSpaceRelease(colorSpace);
    CGImageRelease(raw);
    
    return strip;
}

@end
