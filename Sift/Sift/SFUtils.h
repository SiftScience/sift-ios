// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/** Generic helper functions. */

/** @return the current time stamp in milliseconds. */
NSInteger SFTimestampMillis(void);

/** @return the path to a cache directory. */
NSString *SFCacheDirPath(void);

/**
 * Create a file at path, or do nothing if it has been created already.
 *
 * @return YES on success.
 */
BOOL SFTouchFilePath(NSString *path);

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
