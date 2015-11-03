// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFRotatedFiles.h"

/**
 * Manage directories for `SFQueue` objects.  The directory contents are
 * manipulated with `SFRotatedFiles` objects, which let you may write to
 * the current file, rotate it, etc.
 *
 * Methods return YES on success.
 */
@interface SFQueueDirs : NSObject

/** Keep all managed directories under `rootDirPath`. */
- (instancetype)initWithRootDirPath:(NSString *)rootDirPath;

/** Add and manage a directory for this queue identifier. */
- (BOOL)addDir:(NSString *)identifier;

/**
 * Stop manage the directory of this queue identifier, and also remove
 * the directory if `purge` is YES.
 */
- (BOOL)removeDir:(NSString *)identifier purge:(BOOL)purge;

/**
 * Acquire lock and access the contents of directory of this queue
 * identifier.
 */
- (BOOL)useDir:(NSString *)identifier withBlock:(BOOL (^)(SFRotatedFiles *rotatedFiles))block;

/** Acquire lock and access the contents of all managed directories. */
- (BOOL)useDirsWithBlock:(BOOL (^)(SFRotatedFiles *rotatedFiles))block;

/** Remove everything. */
- (void)removeRootDir;

/** Number of directories managed by an `SFQueueDirs` object. */
@property (readonly) NSInteger numDirs;

@end
