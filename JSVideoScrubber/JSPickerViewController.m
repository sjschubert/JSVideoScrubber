//
//  JSPickerViewController.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 4/18/13.
//  Copyright (c) 2013 jaminschubert. All rights reserved.
//

#import <MobileCoreServices/MobileCoreServices.h>
#import "JSVideoScrubber.h"
#import "JSPickerViewController.h"

@interface JSPickerViewController () <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (weak, nonatomic) IBOutlet JSVideoScrubber *scrubber;
@property (strong, nonatomic) IBOutlet UILabel *duration;
@property (strong, nonatomic) IBOutlet UILabel *offset;

@end

@implementation JSPickerViewController

#pragma mark - Initialization

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)viewDidUnload {
    [self setDuration:nil];
    [self setOffset:nil];
    [super viewDidUnload];
}

#pragma mark - IB Actions

- (IBAction)pickMediAction:(id)sender
{
     UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
     imagePicker.delegate = self;
     
     if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
         [[[UIAlertView alloc] initWithTitle:@"Error"
                                     message:@"Library unavailable"
                                    delegate:self
                           cancelButtonTitle:@"Ok"
                           otherButtonTitles:nil] show];
         return;
     } else {
         imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
         imagePicker.videoQuality = UIImagePickerControllerQualityTypeHigh;
         imagePicker.mediaTypes = @[(__bridge NSString *)kUTTypeMovie];
     }
     
    [self presentViewController:imagePicker animated:YES completion:nil];
}

- (IBAction)clearAssetAction:(id)sender
{
    self.duration.text = @"Duration: 00:00";
    self.offset.text = @"Offset: 00:00";
    
    [self.scrubber reset];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerControllerDidCancel:(UIImagePickerController *) picker
{
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *) picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{        
        AVURLAsset* asset = [AVURLAsset URLAssetWithURL:[info objectForKey:UIImagePickerControllerMediaURL] options:nil];
        NSArray *assetKeysToLoadAndTest = [NSArray arrayWithObjects:@"tracks", @"duration", nil];
  
        __weak JSPickerViewController *ref = self;
        [asset loadValuesAsynchronouslyForKeys:assetKeysToLoadAndTest completionHandler:^(void) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [ref.scrubber setupControlWithAVAsset:asset];

                double total = CMTimeGetSeconds(self.scrubber.duration);

                int min = (int)total / 60;
                int seconds = (int)total % 60;
                self.duration.text = [NSString stringWithFormat:@"Duration: %02d:%02d", min, seconds];
                
                [ref updateOffsetLabel:self.scrubber];
                [ref.scrubber addTarget:self action:@selector(updateOffsetLabel:) forControlEvents:UIControlEventValueChanged];
                
                [ref dismissViewControllerAnimated:YES completion:NULL];
            });
        }];
    });
}

- (void) updateOffsetLabel:(JSVideoScrubber *) scrubber
{
    int min = (int)scrubber.offset / 60;
    int seconds = (int)scrubber.offset % 60;
    self.offset.text = [NSString stringWithFormat:@"Offset: %02d:%02d", min, seconds];
}

@end
