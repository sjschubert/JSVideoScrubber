//
//  JSSimViewController.h
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "JSVideoScrubber.h"
@interface JSSimViewController : UIViewController<UITextFieldDelegate>

@property (weak, nonatomic) IBOutlet UITextField *assetName;
@property (weak, nonatomic) IBOutlet UITextView *assetDirectory;
@property (weak, nonatomic) IBOutlet JSVideoScrubber *jsVideoScrubber;

- (IBAction)clearAssetAction:(id)sender;

@end
