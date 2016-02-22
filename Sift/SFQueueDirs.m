// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "pthread.h"

#import "SFDebug.h"
#import "SFMetrics.h"
#import "SFUtils.h"

#import "SFQueueDirs.h"

static NSString * const SFQueueDirName = @"queue";
static NSString * const SFQueueDirNamePrefix = @"queue-";

/**
 * Remove unrecognizable directories whose contents' last modification
 * time is older than this value.
 */
static const NSTimeInterval SFRemoveDirOlderThan = 600;  // 10 minutes.

static BOOL SFShouldRemove(NSString *targetPath);

static NSString *SFGetIdentifier(NSString *dirName);
static NSString *SFMakeQueueDirName(NSString *identifier);

@interface SFQueueDirs ()

- (NSString *)dirPath:(NSString *)identifier;

@end

@implementation SFQueueDirs {
    NSString *_rootDirPath;
    NSMutableDictionary *_rotatedFilesDict;
    pthread_rwlock_t _lock;  // Using a RW lock is easier than dispatch_barrier_async at the moment...
}

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath {
    self = [super init];
    if (self) {
        _rootDirPath = rootDirPath;
        if (!SFTouchDirPath(_rootDirPath)) {
            self = nil;
            return nil;
        }

        _rotatedFilesDict = [NSMutableDictionary new];
        pthread_rwlock_init(&_lock, NULL);

        NSFileManager *manager = [NSFileManager defaultManager];
        NSError *error;
        NSArray *dirNames = [manager contentsOfDirectoryAtPath:_rootDirPath error:&error];
        if (!dirNames) {
            SF_DEBUG(@"Could not list contents of directory \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
            [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
            self = nil;
            return nil;
        }
        for (NSString *dirName in dirNames) {
            NSString *identifier = SFGetIdentifier(dirName);
            if (identifier) {
                SFRotatedFiles *rotatedFiles = [[SFRotatedFiles alloc] initWithDirPath:[_rootDirPath stringByAppendingPathComponent:dirName]];
                [_rotatedFilesDict setObject:rotatedFiles forKey:identifier];
            }
        }
    }
    return self;
}

- (void)dealloc {
    pthread_rwlock_destroy(&_lock);
    //[super dealloc];  // Provided by compiler!
}

- (NSInteger)numDirs {
    pthread_rwlock_rdlock(&_lock);
    @try {
        return _rotatedFilesDict.count;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)addDir:(NSString *)identifier {
    pthread_rwlock_wrlock(&_lock);
    @try {
        if ([_rotatedFilesDict objectForKey:identifier]) {
            SF_DEBUG(@"Do not overwrite queue dir entry for \"%@\"", identifier);
            return YES;  // Don't overwrite...
        }

        SFRotatedFiles *rotatedFiles = [[SFRotatedFiles alloc] initWithDirPath:[self dirPath:identifier]];
        if (!rotatedFiles) {
            SF_DEBUG(@"Could not create rotated files for \"%@\"", identifier);
            return NO;
        }

        [_rotatedFilesDict setObject:rotatedFiles forKey:identifier];
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)removeDir:(NSString *)identifier purge:(BOOL)purge {
    pthread_rwlock_wrlock(&_lock);
    @try {
        SFRotatedFiles *rotatedFiles = [_rotatedFilesDict objectForKey:identifier];
        if (!rotatedFiles) {
            SF_DEBUG(@"Could not find rotated files dir for identifier to remove \"%@\"", identifier);
            return NO;
        }
        [_rotatedFilesDict removeObjectForKey:identifier];
        if (purge) {
            return [rotatedFiles removeDir];
        } else {
            return YES;
        }
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)useDir:(NSString *)identifier withBlock:(BOOL (^)(SFRotatedFiles *rotatedFiles))block {
    pthread_rwlock_rdlock(&_lock);
    @try {
        // Create SFRotatedFiles on-demand in case that a background NSURLSession wakes up the app, and the app did not properly initialize the SFQueueDirs...
        SFRotatedFiles *rotatedFiles = [_rotatedFilesDict objectForKey:identifier];
        if (!rotatedFiles) {
            // Acquire the write lock.
            pthread_rwlock_unlock(&_lock);
            pthread_rwlock_wrlock(&_lock);
            rotatedFiles = [[SFRotatedFiles alloc] initWithDirPath:[self dirPath:identifier]];
            if (rotatedFiles) {
                [_rotatedFilesDict setObject:rotatedFiles forKey:identifier];
            }
            // We could re-acquire the read lock...
        }

        return block(rotatedFiles);
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)useDirsWithBlock:(BOOL (^)(SFRotatedFiles *rotatedFiles))block {
    pthread_rwlock_rdlock(&_lock);
    @try {
        for (NSString *identifier in _rotatedFilesDict) {
            if (!block([_rotatedFilesDict objectForKey:identifier])) {
                return NO;
            }
        }
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
    return YES;
}

- (void)cleanup {
    pthread_rwlock_rdlock(&_lock);
    @try {
        NSArray *paths = SFListDir(_rootDirPath);
        if (!paths || paths.count == 0) {
            return;
        }

        NSMutableSet *recognizables = [NSMutableSet setWithCapacity:_rotatedFilesDict.count];
        for (NSString *identifier in _rotatedFilesDict) {
            [recognizables addObject:[self dirPath:identifier]];
        }

        for (NSString *path in paths) {
            if (![recognizables containsObject:path] && SFShouldRemove(path)) {
                SFRemoveFile(path);
            }
        }
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (void)removeData {
    pthread_rwlock_rdlock(&_lock);
    @try {
        for (NSString *identifier in _rotatedFilesDict) {
            SFRotatedFiles *rotatedFiles = [_rotatedFilesDict objectForKey:identifier];
            [rotatedFiles removeData];
        }
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (void)removeRootDir {
    pthread_rwlock_wrlock(&_lock);
    @try {
        [_rotatedFilesDict removeAllObjects];
        SFRemoveFile(_rootDirPath);
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (NSString *)dirPath:(NSString *)identifier {
    return [_rootDirPath stringByAppendingPathComponent:SFMakeQueueDirName(identifier)];
}

static NSString *SFGetIdentifier(NSString *dirName) {
    if ([dirName isEqualToString:SFQueueDirName]) {
        return @"";
    } else if ([dirName hasPrefix:SFQueueDirNamePrefix]) {
        return [dirName substringFromIndex:SFQueueDirNamePrefix.length];
    } else {
        return nil;
    }
}

static NSString *SFMakeQueueDirName(NSString *identifier) {
    if (identifier.length > 0) {
        return [NSString stringWithFormat:@"%@%@", SFQueueDirNamePrefix, identifier];
    } else {
        return SFQueueDirName;
    }
}

@end

BOOL SFShouldRemove(NSString *targetPath) {
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if (![manager fileExistsAtPath:targetPath isDirectory:&isDirectory]) {
        return NO;
    } else if (!isDirectory) {
        SF_DEBUG(@"Remove non-directory \"%@\" for QueueDirs object", targetPath);
        return YES;
    }

    NSArray *paths = SFListDir(targetPath);
    if (!paths) {  // Error!
        return NO;
    } else if (paths.count == 0) {
        SF_DEBUG(@"Remove unrecognizable empty directory \"%@\" for QueueDirs object", targetPath);
        return YES;
    }

    // Find the most recnetly modified file.
    NSTimeInterval sinceNow = -1;
    for (NSString *path in paths) {
        NSTimeInterval interval;
        if (SFFileModificationDate(path, &interval)) {
            if(sinceNow < 0 || interval < sinceNow) {
                sinceNow = interval;
            }
        }
    }

    if (sinceNow > SFRemoveDirOlderThan) {
        SF_DEBUG(@"Remove unrecognizable outdated directory \"%@\" for QueueDirs object: %.2f > %.2f", targetPath, sinceNow, SFRemoveDirOlderThan);
        return YES;
    } else {
        return NO;
    }
}
