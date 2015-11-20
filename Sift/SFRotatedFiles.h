// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * Manage files of a directory exclusively, meaning, no two
 * `SFRotatedFiles` objects should share a directory.
 *
 * There is a special file called the current file, and you may rotate
 * it to make it non-current.  The current and non-current file are
 * guarded by different locks and so you may access them simultaneously.
 *
 * NOTE: We use file name pattern to distinguish current and non-current
 * files. A file named "data" is the current file, and a file with name
 * like "data-\d+" is a non-current file (and non-current files are
 * ordered serially).  Other files are ignored and not managed at all
 * except when you remove the entire directory.  You may exploit this
 * feature to store (meta-)data alongside the managed files.
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
- (BOOL)accessNonCurrentFilesWithBlock:(BOOL (^)(NSArray *filePaths))block;

/**
 * Acquire lock and then access both current and non-current files.
 *
 * The files are guaranteed to exist at paths of `filePaths`, but not so
 * at `currentFilePath` (the current file could have not been created
 * yet).
 */
- (BOOL)accessFilesWithBlock:(BOOL (^)(NSString *currentFilePath, NSArray *filePaths))block;

/**
 * Rotate the current file (make it non-current), or do nothing if it
 * has not been created yet.
 */
- (BOOL)rotateFile;

/** Remove the managed directory. */
- (BOOL)removeDir;

@end
