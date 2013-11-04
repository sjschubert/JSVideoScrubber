//
//  JSViewController.m
//  JSVideoScrubber
//
//  Created by jaminschubert on 9/8/12.
//  Copyright (c) 2012 jaminschubert. All rights reserved.
//

#import <AssetsLibrary/AssetsLibrary.h>

#import "JSAppDefines.h"
#import "JSVideoScrubber.h"
#import "JSSimViewController.h"

@interface UIRefreshControl(JSDelays)

- (void) endRefreshingAfterDelay:(CGFloat) f;

@end

@implementation UIRefreshControl (JSDelays)

- (void) endRefreshingAfterDelay:(CGFloat) f
{
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC));
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self endRefreshing];
    });
}

@end

@interface JSSimViewController () <UITableViewDelegate, UITableViewDataSource, UIImagePickerControllerDelegate>

@property (strong, nonatomic) UITableViewController *tableViewController;
@property (strong, nonatomic) UIRefreshControl *refreshControl;

@property (weak, nonatomic) IBOutlet JSVideoScrubber *jsVideoScrubber;
@property (strong, nonatomic) IBOutlet UITableView *videosTableView;
@property (strong, nonatomic) IBOutlet UIActivityIndicatorView *loadingView;

@property (strong, nonatomic) ALAssetsLibrary *assetLib;

@property (weak, nonatomic) IBOutlet UILabel *duration;
@property (weak, nonatomic) IBOutlet UILabel *offset;
@property (strong, nonatomic) NSString *documentDirectory;
@property (strong, nonatomic) NSMutableArray *assetPaths;

@property (strong, nonatomic) NSIndexPath *currentSelection;

@end

@implementation JSSimViewController

@synthesize jsVideoScrubber;

#pragma mark - UIView

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.title = @"Scrubber Demo";
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    
    self.tableViewController = [[UITableViewController alloc] init];
    self.tableViewController.tableView = self.videosTableView;
    
    [self addChildViewController:self.tableViewController];
    [self.tableViewController didMoveToParentViewController:self];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.refreshControl.tintColor = [UIColor whiteColor];
    self.tableViewController.refreshControl = self.refreshControl;
    [self.refreshControl addTarget:self action:@selector(handleRefresh:) forControlEvents:UIControlEventValueChanged];
    
    self.documentDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    
    self.assetLib = [[ALAssetsLibrary alloc] init];
    self.assetPaths = [NSMutableArray array];

    self.loadingView.hidesWhenStopped = YES;
    self.videosTableView.alpha = 0.0f;
}

- (void)viewDidUnload
{
    [self setJsVideoScrubber:nil];
    [self setDuration:nil];
    [self setOffset:nil];
    [self setVideosTableView:nil];
    
    [super viewDidUnload];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    self.duration.text = @"Duration: 00:00";
    self.offset.text = @"Offset: 00:00";

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self scanForAssets];
    });
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
    [super touchesBegan:touches withEvent:event];
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

#pragma mark - UITableViewDelegate / UITableViewDataSource

-(NSInteger) numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.assetPaths count];
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return @"Detected Assets (Pull To Refresh)";
}

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"JSAssetCellId";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    cell.textLabel.text = [self.assetPaths[indexPath.row] lastPathComponent];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.highlightedTextColor = kJSActiveColor;
    cell.backgroundColor = kJSBackgoundColor;
    return cell;
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.currentSelection && (self.currentSelection.row == indexPath.row)) {
        return;
    }
    
    AVURLAsset* asset = nil;
    
    if (js_is_simulator) {
        NSString *path = self.assetPaths[indexPath.row];
        NSURL* url = [NSURL fileURLWithPath:[self.documentDirectory stringByAppendingPathComponent:path]];
        asset = [AVURLAsset URLAssetWithURL:url options:nil];
    } else {
        asset = [AVURLAsset URLAssetWithURL:self.assetPaths[indexPath.row] options:nil];
    }
    
    
    __weak JSSimViewController *ref = self;
    
    NSArray *keys = [NSArray arrayWithObjects:@"tracks", @"duration", nil];
    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^(void) {
        ref.duration.text = @"Duration: N/A";
        ref.offset.text = @"Offset: N/A";
        
        [ref.jsVideoScrubber setupControlWithAVAsset:asset];

        double total = CMTimeGetSeconds(ref.jsVideoScrubber.duration);
        
        int min = (int)total / 60;
        int seconds = (int)total % 60;
        ref.duration.text = [NSString stringWithFormat:@"Duration: %02d:%02d", min, seconds];
        
        [ref updateOffsetLabel:self.jsVideoScrubber];
        [ref.jsVideoScrubber addTarget:self action:@selector(updateOffsetLabel:) forControlEvents:UIControlEventValueChanged];
        ref.currentSelection = indexPath;
    }];
}

#pragma mark - UIRefresh Cheat

- (void) handleRefresh:(id) sender
{
    [self scanForAssets];
}

#pragma mark - Support

- (void) setupJSVideoScrubber:(AVAsset *) asset
{
    [self.jsVideoScrubber setupControlWithAVAsset:asset];
}

- (void) updateOffsetLabel:(JSVideoScrubber *) scrubber
{
    int min = (int)self.jsVideoScrubber.offset / 60;
    int seconds = (int)self.jsVideoScrubber.offset % 60;
    self.offset.text = [NSString stringWithFormat:@"Offset: %02d:%02d", min, seconds];
}


- (void) scanForAssets
{
    [self.assetPaths removeAllObjects];
    
    if (js_is_simulator) {
        [self scanSimulatorForAssets];
    } else {
        [self scanLibraryForAssets];
    }
}

- (void) scanSimulatorForAssets
{
    NSError *error = nil;
    NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:self.documentDirectory error:&error];
    
    if (!contents) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Error occured scanning docs directory" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
        NSLog(@"error scanning directory: %@", error);
    }
    
    NSPredicate *fltr = [NSPredicate predicateWithFormat:@"self ENDSWITH[c] '.mov'"];
    [self.assetPaths addObjectsFromArray:[contents filteredArrayUsingPredicate:fltr]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIView animateWithDuration:0.25f
             animations:^{
                 self.videosTableView.alpha = 1.0f;
             }
             completion:^(BOOL finished) {
                 [self.loadingView stopAnimating];
                 [self.videosTableView reloadData];
                 [self.refreshControl endRefreshingAfterDelay:0.1];
             }
         ];
    });
}

- (void) scanLibraryForAssets
{
    [self.assetLib enumerateGroupsWithTypes:ALAssetsGroupAll
        usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
            if (!group) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [UIView animateWithDuration:0.25f
                         animations:^{
                             self.videosTableView.alpha = 1.0f;
                         }
                         completion:^(BOOL finished) {
                             [self.loadingView stopAnimating];
                             [self.videosTableView reloadData];
                             [self.refreshControl endRefreshingAfterDelay:0.1];
                         }
                     ];
                });
            }
            
            [group enumerateAssetsUsingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                if (![[result valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo]) {
                    return;
                }

                [self.assetPaths addObject:[result valueForProperty:ALAssetPropertyAssetURL]];
            }];
        }
        failureBlock:^(NSError *error) {
            [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Error occured scanning camera roll for assets" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil] show];
            NSLog(@"error scanning directory: %@", error);
        }
     ];
}

@end
