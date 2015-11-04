// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFUploader.h"

typedef void (^CompletionHandlerType)(void);

/** Private methods of `SFUploader`. */
@interface SFUploader ()

/**
 * Collect events from non-current files of all queues and write them
 * into a list request.  These files are called the "source files" of an
 * upload.
 *
 * @return YES on success.
 */
- (BOOL)collectEventsInto:(NSFileHandle *)listRequest fromFilePaths:(NSMutableArray *)sourceFilePaths;

/** Remove the source files. */
- (void)removeSourceFiles:(NSSet *)sourceFilePaths;

/**
 * A callback on completion of a HTTP request.  You should use this for
 * testing only.
 */
@property (nonatomic, copy) CompletionHandlerType completionHandler;

@end
