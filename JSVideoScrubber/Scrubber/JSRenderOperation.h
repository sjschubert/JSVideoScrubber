//
//  JSRenderOperation.h
//  JSVideoScrubber
//
//  Created by jaminschubert on 5/11/13.
//  Copyright (c) 2013 jaminschubert. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@class JSRenderOperation;

typedef void (^JSRenderOperationCompletionBlock)(UIImage *strip, NSError *error);

@interface JSRenderOperation : NSOperation

@property (nonatomic, copy) JSRenderOperationCompletionBlock renderCompletionBlock;

- (id) initWithAsset:(AVAsset *)asset targetFrame:(CGRect) frame;
- (id) initWithAsset:(AVAsset *)asset indexAt:(NSArray *)indexes targetFrame:(CGRect) frame;

@end
