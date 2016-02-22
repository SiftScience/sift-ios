// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/** Private methods of `Sift`. */
@interface Sift ()

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath operationQueue:(NSOperationQueue *)operationQueue queueDir:(SFQueueDirs *)queueDirs uploader:(SFUploader *)uploader;

/** Set timer period or cancel timer. */
- (void)configureTimer:(NSTimer *)timer period:(NSTimeInterval *)period newPeriod:(NSTimeInterval)newPeriod;

/**
 * Issue a method call, based on which timer is fired, in the background
 * queue.
 */
- (void)enqueueMethod:(NSTimer *)timer;

/** Gather metrics and device properties report. */
- (void)report;

/** Call each component's `cleanup` method. */
- (void)cleanup;

@end
