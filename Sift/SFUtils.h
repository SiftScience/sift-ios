// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/** Generic helper functions. */

/** Short hand of NSAssert(false, ...) */
#define SFFail() NSAssert(false, @"SFFail() at %s:%d", __FUNCTION__, __LINE__)

/** @return the current time stamp in milliseconds. */
NSInteger SFTimestampMillis(void);

/** @return snake case string, e.g., "camelCase" to "camel_case". */
NSString *SFCamelCaseToSnakeCase(NSString *camelCase);

/** @return the path to a cache directory. */
NSString *SFCacheDirPath(void);

/** @return file or directory attributes. */
NSDictionary *SFFileAttrs(NSString *path);

/** @return YES if file exists at path */
BOOL SFFileExists(NSString *path);

/**
 * Store file creation date since now in the output parameter.
 *
 * @return YES on success.
 */
BOOL SFFileCreationDate(NSString *path, NSTimeInterval *sinceNow);

/**
 * Store file modification date since now in the output parameter.
 *
 * @return YES on success.
 */
BOOL SFFileModificationDate(NSString *path, NSTimeInterval *sinceNow);
BOOL SFFileModificationTimestamp(NSString *path, NSInteger *timestamp);

/** @return directory contents as an array of paths. */
NSArray *SFListDir(NSString *path);

/** @return YES if the directory is empty. */
BOOL SFIsDirEmpty(NSString *path);

/**
 * Create a file at path, or do nothing if it has been created already.
 *
 * @return YES on success.
 */
BOOL SFTouchFilePath(NSString *path);

/**
 * Create a dir at path, or do nothing if it has been created already.
 *
 * @return YES on success.
 */
BOOL SFTouchDirPath(NSString *path);

/**
 * Remove file or directory at path.
 *
 * @return YES on success.
 */
BOOL SFRemoveFile(NSString *path);

/**
 * Remove files in a directory but keep that directory.
 *
 * @return YES on success.
 */
BOOL SFRemoveFilesInDir(NSString *path);

/**
 * @return an object from the contents of a file, parsed in JSON format,
 * or nil on failure.
 */
id SFReadJsonFromFile(NSString *filePath);

/**
 * Serialize an object into JSON and write it to a file as its contents.
 *
 * @return YES on success.
 */
BOOL SFWriteJsonToFile(id object, NSString *filePath);
