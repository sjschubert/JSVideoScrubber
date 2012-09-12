//
//  JSViewController.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import "JSViewController.h"

@interface JSViewController ()

@property (strong) NSString *documentDirectory;

@end

@implementation JSViewController
@synthesize assetName;
@synthesize assetDirectory;
@synthesize jsVideoScrubber;

#pragma mark - UIView

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

- (void)viewDidUnload
{
    [self setAssetDirectory:nil];
    [self setAssetName:nil];
    [self setJsVideoScrubber:nil];
    [super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.assetDirectory.text = [self.documentDirectory stringByReplacingOccurrencesOfString:@" " withString:@"\\ "];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark - UITextField

- (BOOL) textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    
    if (textField.text.length == 0) {
        UIAlertView *msg = [[UIAlertView alloc] initWithTitle:@"Invalid Asset"
                                                      message:@"The asset name must be specified..."
                                                     delegate:nil
                                            cancelButtonTitle:@"Ok"
                                            otherButtonTitles:nil];
        [msg show];
    } else {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL* url = [NSURL fileURLWithPath:[self.documentDirectory stringByAppendingPathComponent:self.assetName.text]];
            AVURLAsset* asset = [AVURLAsset URLAssetWithURL:url options:nil];
            
            NSArray *assetKeysToLoadAndTest = [NSArray arrayWithObjects:@"tracks", @"duration", nil];
            [asset loadValuesAsynchronouslyForKeys:assetKeysToLoadAndTest completionHandler:^(void) {
                [self setupJSVideoScrubber:asset];
            }];
        });
    }
    
    return YES;
}

#pragma mark - IB Actions

- (IBAction)clearAssetAction:(id)sender
{
    self.assetName.text = @"";
}

#pragma mark - Internal

- (void) setupJSVideoScrubber:(AVAsset *) asset
{
    [self.jsVideoScrubber setupControlWithAVAsset:asset];
}

@end
