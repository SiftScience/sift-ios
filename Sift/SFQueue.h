// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"
#import "SFQueueDirs.h"

/**
 * A queue is basically a group of Record IO files that are rotated; you
 * keep appending events to the current Record IO file until it is
 * rotated.  The criteria of when the current Record IO file should be
 * rotated is specified in `SFQueueConfig`.
 */
@interface SFQueue : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config operationQueue:(NSOperationQueue *)operationQueue queueDirs:(SFQueueDirs *)queueDirs;

/**
 * Write an event to the file asynchronously.
 *
 * Because this call is asynchronous, it is safe to be called in the
 * main thread without blocking the main thread.
 */
- (void)append:(NSDictionary *)event;

/**
 * Examine the current Record IO file and rotate it if criteria
 * specified in the `SFQueueConfig` are met.  This method is blocking.
 *
 * @return YES on success (even if nothing has been rotated).
 */
- (BOOL)maybeRotateFile;

/**
 * Rotate the current Record IO file.
 *
 * @return YES on success.
 */
- (BOOL)rotateFile;

@end
