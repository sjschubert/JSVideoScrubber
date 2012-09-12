//
//  JSVideoScrubber.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import "JSVideoScrubber.h"

@interface JSVideoScrubber ()

@property (strong) AVAssetImageGenerator *assetImageGenerator;
@property (strong) NSMutableDictionary *imageStrip;
@property (assign) CMTime duration;
@property (assign) size_t sourceWidth;
@property (assign) size_t sourceHeight;

- (AVAssetImageGenerator *) generatorForAsset:(AVAsset *) asset;
- (NSArray *) generateOffsets:(AVAsset *) asset;
- (void) updateImageStrip:(AVAssetImageGenerator *) generator atIndex:(CMTime) offset;

@end

@implementation JSVideoScrubber

#pragma mark - Memory

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {

    }
    
    return self;
}

#pragma mark - UIView

- (void)drawRect:(CGRect) rect
{

}

#pragma mark - Interface

- (void) setupControlWithAVAsset:(AVAsset *) asset
{
    AVAssetImageGenerator *generator = [self generatorForAsset:asset];
    
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef image = [generator copyCGImageAtTime:CMTimeMakeWithSeconds(0.0, 1) actualTime:&actualTime error:&error];
    
    if (error) {
        NSLog(@"Error copying reference image.");
    }
    
    self.sourceWidth = CGImageGetWidth(image);
    self.sourceHeight = CGImageGetHeight(image);
    
    [self setupControlWithAVAsset:asset indexedAt:[self generateOffsets:asset]];
}

- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    AVAssetImageGenerator *generator = [self generatorForAsset:asset];
    
    for (NSNumber *number in requestedTimes)
    {
        double offset = [number doubleValue];
        
        if (offset < 0 || offset > CMTimeGetSeconds(asset.duration))
            continue;
        
        [self updateImageStrip:generator atIndex:CMTimeMakeWithSeconds(offset, 1)];
    }
    
    self.duration = asset.duration;
}

#pragma mark - Internal

- (AVAssetImageGenerator *) generatorForAsset:(AVAsset *) asset
{
    //only create one generator, not quite a singlton, but we don't need more than one
    if (self.assetImageGenerator == nil) {
        self.assetImageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    }
    
    return self.assetImageGenerator;
}

- (NSArray *) generateOffsets:(AVAsset *) asset
{
    CGFloat aspect = (self.sourceWidth * 1.0f) / self.sourceHeight;
    
    CGFloat idealInterval = self.frame.size.height * aspect;
    CGFloat intervals = self.frame.size.width / idealInterval;
    
    double duration = CMTimeGetSeconds(asset.duration);
    double offset = duration / intervals;
    
    NSLog(@"what is my standard offset: %f", offset);
    NSMutableArray *offsets = [NSMutableArray array];

    double time = 0.0f;
    
    while (time < duration) {
        [offsets addObject:[NSNumber numberWithDouble:time]];
        time += offset;
    }
    
    return offsets;
}

- (void) updateImageStrip:(AVAssetImageGenerator *)generator atIndex:(CMTime)offset
{
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef image = [generator copyCGImageAtTime:offset actualTime:&actualTime error:&error];
    
    if (error) {
        NSLog(@"Error copying image at index %f: %@", CMTimeGetSeconds(offset), [error localizedDescription]);
    }
    
    CFRetain(image); //retain per the Get memory mgmt model in apple docs
    
    [self.imageStrip setObject:CFBridgingRelease(image) forKey:[NSNumber numberWithDouble:CMTimeGetSeconds(actualTime)]];
}

@end
