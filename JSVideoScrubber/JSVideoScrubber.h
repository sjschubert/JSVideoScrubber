//
//  JSVideoScrubber.h
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface JSVideoScrubber : UIControl

@property (assign) CMTime duration;
@property (assign) CGFloat markerOffset;

- (void) setupControlWithAVAsset:(AVAsset *) asset;
- (void) setupControlWithAVAsset:(AVAsset *) asset indexedAt:(NSArray *) requestedTimes;

@end
