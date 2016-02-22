// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"

/**
 * Examine the file attributes and determine if we should rotate the
 * current file based on `SFQueueConfig`.
 *
 * @return YES if we should rotate the current file.
 */
BOOL SFQueueShouldRotateFile(NSString *currentFilePath, SFQueueConfig *config);

/**
 * Private methods of `SFQueue`, which should be called in a background
 * queue so that the caller will not block the main thread.
 *
 * Methods return YES on success.
 */
@interface SFQueue ()

/** Read queue state from file. */
- (void)loadState;

/** Write queue state to file. */
- (void)saveState;

/**
 * Based on `SFQueueConfig`, optionally write event to file and then
 * optionally rotate the current file.
 */
- (void)maybeWriteEventToFile:(NSDictionary *)event;

/** Write event to the current file. */
- (BOOL)writeEventToFile:(NSDictionary *)event;

@end
