// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"

BOOL SFQueueShouldRotateFile(NSFileManager *manager, NSString *currentFilePath, SFQueueConfig *config);

@interface SFQueue ()

// NOTE: The following methods are only called in the background queue.

- (void)maybeWriteEventToFile:(NSDictionary *)event;

- (BOOL)writeEventToFileWhenDifferent:(NSDictionary *)event lastEvent:(NSDictionary *)lastEvent;

- (BOOL)writeEventToFile:(NSDictionary *)event;

@end
