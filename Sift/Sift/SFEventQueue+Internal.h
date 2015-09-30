// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFConfig.h"
#import "SFEventFileManager.h"
#import "SFEventFileStore.h"
#import "SFEventFileUploader.h"

@interface SFEventQueue ()

- (void)enqueuePersistEvent:(NSDictionary *)event;

- (void)enqueueCheckOrRotateCurrentEventFile:(NSTimer *)timer;

- (void)enqueueUploadEventFiles:(NSTimer *)timer;

// NOTE: The following methods are only called in the background queue.

- (void)persistEvent:(NSDictionary *)event;

- (BOOL)writeToCurrentEventFileIfDifferentWithEvent:(NSDictionary *)event lastEvent:(NSDictionary *)lastEvent;

- (BOOL)writeToCurrentEventFileWithEvent:(NSDictionary *)event;

- (void)checkOrRotateCurrentEventFile;

- (BOOL)shouldRotateCurrentEventFile:(NSString *)currentEventFilePath manager:(NSFileManager *)manager;

- (void)uploadEventFiles;

@end
