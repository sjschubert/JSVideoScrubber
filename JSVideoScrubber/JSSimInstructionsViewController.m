//
//  JSimInstructionsViewController.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/22/13.
//  Copyright (c) 2013 jaminschubert. All rights reserved.
//

#import "JSAppDefines.h"
#import "TTTAttributedLabel.h"
#import "JSSimViewController.h"
#import "JSSimInstructionsViewController.h"

@interface JSimInstructionsViewController ()

@property (strong, nonatomic) IBOutlet TTTAttributedLabel *helpText;
@property (strong, nonatomic) IBOutlet UIButton *demoBtn;

@end

@implementation JSimInstructionsViewController

#pragma mark - Memory

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setupHelpText];
    
    [self.demoBtn setTitleColor:kJSInteractiveColor forState:UIControlStateNormal];
    [self.demoBtn setTitleColor:kJSHighlightedColor forState:UIControlStateHighlighted];
    [self.demoBtn setTitleColor:kJSHighlightedColor forState:UIControlStateSelected];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - IB Actions

- (IBAction)demoAction:(id)sender
{
    JSSimViewController *controller = [[JSSimViewController alloc] initWithNibName:@"JSSimViewController" bundle:nil];
    [self.navigationController pushViewController:controller animated:YES];
}

#pragma MARK - TTTAttributedLabel

- (void)attributedLabel:(TTTAttributedLabel *)label didSelectLinkWithURL:(NSURL *)url
{
    [[UIApplication sharedApplication] openURL:url];
}

#pragma mark - Support

- (void) setupHelpText
{
    self.helpText.font = [UIFont fontWithName:@"Helvetica" size:20.0f];
    
    self.helpText.text = @"1. Use the excellent utility SimPholders to locate the application documents directory for this app in the simulator, and drop in your .mov files.\n\n2. Tap on the file name in the table to load the video in the scrubber.";
    
    NSRange r = [self.helpText.text rangeOfString:@"SimPholders"];
    [self.helpText addLinkToURL:[NSURL URLWithString:@"http://simpholders.com/"] withRange:r];
}

@end
