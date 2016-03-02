// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

/**
 * Since the volume of motion data is huge, we don't collect it in the
 * background continuously.  Instead, we let the app initiate the
 * collection.  The app has to determine when is important enough to
 * justify the resources (battery/storage/bandwidth) for a collection.
 */
@interface SFMotionReporter : NSObject

/**
 * Start a collection after `delay` seconds for `period` seconds of
 * time, and collect `numSamples` of data per second.
 */
- (void)collect:(NSTimeInterval)delay period:(NSTimeInterval)period numSamples:(int)numSamples;

@end
