// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFUploader.h"

typedef void (^CompletionHandlerType)(void);

@interface SFUploader ()

- (BOOL)collectEventsInto:(NSFileHandle *)listRequest fromFilePaths:(NSMutableArray *)sourceFilePaths;

- (void)removeSourceFiles:(NSSet *)sourceFilePaths;

// For testing (must be 'copy', don't retain).
@property (nonatomic, copy) CompletionHandlerType completionHandler;

@end
