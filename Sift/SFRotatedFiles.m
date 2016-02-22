// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFMetrics.h"
#import "SFUtils.h"

#import "SFRotatedFiles.h"
#import "SFRotatedFiles+Private.h"

static NSString * const SFCurrentFileName = @"data";
static NSString * const SFFileNamePrefix = @"data-";

@implementation SFRotatedFiles {
    NSString *_dirPath;
    NSString *_currentFilePath;

    // Cache the opened file handle so that we don't have to open it every time.
    NSFileHandle *_currentFile;

    // Acquire these locks by the declaration order.
    NSObject *_currentFileLock;
    NSObject *_nonCurrentFilesLock;
}

- (instancetype)initWithDirPath:(NSString *)dirPath {
    self = [super init];
    if (self) {
        _dirPath = dirPath;
        if (!SFTouchDirPath(_dirPath)) {
            self = nil;
            return nil;
        }

        _currentFilePath = [_dirPath stringByAppendingPathComponent:SFCurrentFileName];
        _currentFile = nil;

        _currentFileLock = [NSObject new];
        _nonCurrentFilesLock = [NSObject new];
    }
    return self;
}

- (BOOL)writeCurrentFileWithBlock:(BOOL (^)(NSFileHandle *))block {
    @synchronized(_currentFileLock) {
        return block([self currentFile]);
    }
}

- (void)removeCurrentFile {
    @synchronized(_currentFileLock) {
        [self closeCurrentFile];
        SFRemoveFile(_currentFilePath);
    }
}

- (BOOL)accessNonCurrentFilesWithBlock:(BOOL (^)(NSArray *filePaths))block {
    @synchronized(_nonCurrentFilesLock) {
        return block([self filePaths]);
    }
}

- (BOOL)accessFilesWithBlock:(BOOL (^)(NSString *currentFilePath, NSArray *filePaths))block {
    @synchronized(_currentFileLock) {
        @synchronized(_nonCurrentFilesLock) {
            return block(_currentFilePath, [self filePaths]);
        }
    }
}

- (BOOL)rotateFile {
    @synchronized(_currentFileLock) {
        @synchronized(_nonCurrentFilesLock) {
            NSFileManager *manager = [NSFileManager defaultManager];

            if (![manager isWritableFileAtPath:_currentFilePath]) {
                return YES;   // Nothing to rotate...
            }

            NSArray *filePaths = [self filePaths];
            if (!filePaths) {
                return NO;
            }

            int largestIndex = -1;
            if (filePaths.count > 0) {
                largestIndex = [self fileIndex:[[filePaths lastObject] lastPathComponent]];
            }
            NSString *newFileName = [NSString stringWithFormat:@"%@%d", SFFileNamePrefix, (largestIndex + 1)];
            NSString *newFilePath = [_dirPath stringByAppendingPathComponent:newFileName];

            // Close the current event file handle before rotating it.
            [self closeCurrentFile];

            NSError *error;
            if (![manager moveItemAtPath:_currentFilePath toPath:newFilePath error:&error]) {
                SF_DEBUG(@"Could not rotate the current file \"%@\" to \"%@\" due to %@", _currentFilePath, newFilePath, [error localizedDescription]);
                [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
                return NO;
            }

            SF_DEBUG(@"The current file is rotated to \"%@\"", newFilePath);
            return YES;
        }
    }
}

- (void)removeData {
    @synchronized(_currentFileLock) {
        @synchronized(_nonCurrentFilesLock) {
            SFRemoveFilesInDir(_dirPath);
        }
    }
}


- (BOOL)removeDir {
    @synchronized(_currentFileLock) {
        @synchronized(_nonCurrentFilesLock) {
            [self closeCurrentFile];
            return SFRemoveFile(_dirPath);
        }
    }
}

// NOTE: You _must_ acquire respective locks before calling methods below.

- (NSFileHandle *)currentFile {
    if (!_currentFile) {
        SF_DEBUG(@"Open the current file \"%@\"", _currentFilePath);

        if (!SFTouchFilePath(_currentFilePath)) {
            return nil;
        }

        _currentFile = [NSFileHandle fileHandleForWritingAtPath:_currentFilePath];
        if (!_currentFile) {
            SF_DEBUG(@"Could not open \"%@\" for writing", _currentFilePath);
            [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
            return nil;
        }

        [_currentFile seekToEndOfFile];
    }
    return _currentFile;
}

- (void)closeCurrentFile {
    if (_currentFile) {
        [_currentFile closeFile];
        _currentFile = nil;
    }
}

- (NSArray *)filePaths {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *fileNames = [manager contentsOfDirectoryAtPath:_dirPath error:&error];
    if (!fileNames) {
        SF_DEBUG(@"Could not list contents of directory \"%@\" due to %@", _dirPath, [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
        return nil;
    }

    fileNames = [fileNames filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id fileName, NSDictionary *bindings) {
        return [self fileIndex:fileName] >= 0;
    }]];

    // Sort file names by the file index (NOT by alphabetic order).
    fileNames = [fileNames sortedArrayUsingComparator:^NSComparisonResult(NSString *fileName1, NSString *fileName2) {
        return [self fileIndex:fileName1] - [self fileIndex:fileName2];
    }];

    NSMutableArray *paths = [NSMutableArray arrayWithCapacity:fileNames.count];
    for (NSString *fileName in fileNames) {
        [paths addObject:[_dirPath stringByAppendingPathComponent:fileName]];
    }
    return paths;
}

- (int)fileIndex:(NSString *)fileName {
    if (![fileName hasPrefix:SFFileNamePrefix]) {
        return -1;
    }
    NSScanner *scanner = [NSScanner scannerWithString:[fileName substringFromIndex:SFFileNamePrefix.length]];
    int index;
    if (![scanner scanInt:&index]) {
        return -1;
    }
    return index;
}

@end
