// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFRotatedFiles : NSObject

- (instancetype)initWithDirPath:(NSString *)dirPath;

- (BOOL)writeCurrentFileWithBlock:(BOOL (^)(NSFileHandle *handle))block;

- (void)removeCurrentFile;

- (BOOL)accessNonCurrentFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSArray *filePaths))block;

- (BOOL)accessFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSString *currentFilePath, NSArray *filePaths))block;

- (BOOL)rotateFile;

- (BOOL)removeDir;

@end
