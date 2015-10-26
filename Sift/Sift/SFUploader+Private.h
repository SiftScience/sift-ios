// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

//typedef void (^CompletionHandlerType)(void);

@interface SFUploader ()

- (BOOL)collectEventsInto:(NSFileHandle *)listRequest fromFilePaths:(NSMutableArray *)sourceFilePaths;

- (void)removeSourceFiles:(NSSet *)sourceFilePaths;

// For testing.
//@property CompletionHandlerType completionHandler;

@end
