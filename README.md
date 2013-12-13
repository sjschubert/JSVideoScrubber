JSVideoScrubber
===============

First of all, thanks to [grayscaletx](https://github.com/grayscaletx "grayscaletx") for grpahic design work and UX feedback, and thanks to [schlu](https://github.com/schlu "schlu") for helping to sovle some difficult issues involving AVFoundation API's used to by this control.

This is a simple iOS 7 video scrubber control. There is an 'alt' branch which has a more native iOS 7 look and feel, but both have the same behavior.

To use:

1. Checkout the branch (master | alt) for the design you want to use.
2. Copy the _Scubber_ folder into your project directory, and then import into XCode (no other source from this repo is needed).
3. Add a UIView subview on the screen you want to display the scrubber on, and set its class property to _JSVideoScrubber_ in the identity inspector.  The size of the control can vary, however it was tested at 44x320. Results might vary.
4. The following snippet is an example of how to load an asset into the scrubber:
```
__weak MyController *ref = self;
    
    NSArray *keys = [NSArray arrayWithObjects:@"tracks", @"duration", nil];
    [asset loadValuesAsynchronouslyForKeys:keys completionHandler:^(void) {
        [ref.scrubber setupControlWithAVAsset:asset];

        double total = CMTimeGetSeconds(ref.jsVideoScrubber.duration);
        
        ... update label with duration of the asset
        
        //called everytime the user updates the offset into the video stream, slave our video playback to this
        [ref.jsVideoScrubber addTarget:self action:@selector(updateVideoOffset:) forControlEvents:UIControlEventValueChanged];
    }];
```

The following iOS frameworks are required by the control:
  * QuartzCore.framework
  * AVFoundation.framework
  * CoreGraphics.framework
  * UIKit.framework
  * Foundation.framework
  * CoreMedia.framework
  
You can run the demo on either a simulator or your phone. If running on the simulator, you will need to add video assets to your app's Documents directory in the simulator (I highly recommend the  [SimPholders](http://simpholders.com/ "SimPholders") mentioned in the instructions).  If running on the phone, the demo app will ask for access to your photo roll, and will display any video assets in your library.
