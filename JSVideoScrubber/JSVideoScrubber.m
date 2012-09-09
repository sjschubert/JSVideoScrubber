//
//  JSVideoScrubber.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import "JSVideoScrubber.h"

@interface JSVideoScrubber ()

@property (strong) NSMutableDictionary *imageStrip;
@property (assign) CMTime duration;

- (void) updateImageStrip:(AVAssetImageGenerator *) generator atIndex:(CMTime) offset;

@end

@implementation JSVideoScrubber

#pragma mark - Memory

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

#pragma mark - UIView

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

#pragma mark - Interface

- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes
{
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    
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

- (void) updateImageStrip:(AVAssetImageGenerator *)generator atIndex:(CMTime)offset
{
    CMTime actualTime;
    NSError *error = nil;
    
    CGImageRef image = [generator copyCGImageAtTime:offset actualTime:&actualTime error:&error];
    
    if (error)
    {
        NSLog(@"Error copying image at index %f: %@", CMTimeGetSeconds(offset), [error localizedDescription]);
    }
    
    CFRetain(image); //retain per the Get memory mgmt model in apple docs

    [self.imageStrip setObject:CFBridgingRelease(image) forKey:[NSNumber numberWithDouble:CMTimeGetSeconds(actualTime)]];
}

@end
