// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/** Private methods of `Sift`. */
@interface Sift ()

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath operationQueue:(NSOperationQueue *)operationQueue queueDir:(SFQueueDirs *)queueDirs uploader:(SFUploader *)uploader;

/** Issue a call to `upload` in the background queue. */
- (void)enqueueUpload:(NSTimer *)timer;

/** Issue a call to `report` in the background queue. */
- (void)enqueueReport:(NSTimer *)timer;

/** Call `SFMetricsReporter` to collect and report metrics. */
- (void)report;

@end
