// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * Manage files of a directory exclusively, meaning, no two
 * `SFRotatedFiles` objects should share a directory.
 *
 * There is a special file called the current file, and you may rotate
 * it to make it non-current and leave room for the next current file.
 *
 * Methods return YES on success.
 */
@interface SFRotatedFiles : NSObject

/** Make this `SFRotatedFiles` object manage this directory. */
- (instancetype)initWithDirPath:(NSString *)dirPath;

/**
 * Acquire lock and then access the current file (and create the current
 * file if it does not exist).
 */
- (BOOL)writeCurrentFileWithBlock:(BOOL (^)(NSFileHandle *handle))block;

/**
 * Remove the current file (you should call this after corruption), or
 * do nothing if it has not been created yet.
 */
- (void)removeCurrentFile;

/**
 * Acquire lock and then access all non-current files.
 *
 * The files are guaranteed to exist at paths of `filePaths`.
 */
- (BOOL)accessNonCurrentFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSArray *filePaths))block;

/**
 * Acquire lock and then access current and non-current files.
 *
 * The files are guaranteed to exist at paths of `filePaths`, but not so
 * at `currentFilePath` (the current file could have not been created
 * yet).
 */
- (BOOL)accessFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSString *currentFilePath, NSArray *filePaths))block;

/**
 * Rotate the current file (make it non-current), or do nothing if it
 * has not been created yet.
 */
- (BOOL)rotateFile;

/** Remove the managed directory. */
- (BOOL)removeDir;

@end
