// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFEventFileStore : NSObject

- (instancetype)initWithEventDirPath:(NSString *)eventDirPath;

- (BOOL)writeCurrentEventFileWithBlock:(BOOL (^)(NSFileHandle *handle))block;

- (void)removeCurrentEventFile;

- (BOOL)accessEventFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSArray *eventFilePaths))block;

- (BOOL)accessAllEventFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSString *currentEventFilePath, NSArray *eventFilePaths))block;

- (BOOL)rotateCurrentEventFile;

- (BOOL)removeEventDir;

@end
