// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFMetrics.h"

#import "SFRotatedFiles.h"
#import "SFRotatedFiles+Private.h"

static NSString * const SFCurrentFileName = @"data";
static NSString * const SFFileNamePrefix = @"data-";

@implementation SFRotatedFiles {
    NSString *_dirPath;
    NSString *_currentFilePath;

    // Cache the opened file handle so that we don't have to open it every time.
    NSFileHandle *_currentFile;

    NSFileManager *_manager;

    // Acquire these locks by the declaration order.
    NSObject *_currentFileLock;
    NSObject *_nonCurrentFilesLock;
}

- (instancetype)initWithDirPath:(NSString *)dirPath {
    self = [super init];
    if (self) {
        _dirPath = dirPath;
        _currentFilePath = [_dirPath stringByAppendingPathComponent:SFCurrentFileName];

        _currentFile = nil;

        _manager = [NSFileManager defaultManager];

        SFDebug(@"Create rotated files dir \"%@\"", _dirPath);
        NSError *error;
        if (![_manager createDirectoryAtPath:_dirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            SFDebug(@"Could not create rotated files dir \"%@\" due to %@", _dirPath, [error localizedDescription]);
            [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileOperationErrors];
            self = nil;
            return nil;
        }

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

        NSError *error;
        if (![_manager removeItemAtPath:_currentFilePath error:&error]) {
            SFDebug(@"Could not remove the current file \"%@\" due to %@", _currentFilePath, [error localizedDescription]);
            [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileOperationErrors];
        }
    }
}

- (BOOL)accessNonCurrentFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSArray *filePaths))block {
    @synchronized(_nonCurrentFilesLock) {
        return block(_manager, [self filePaths]);
    }
}

- (BOOL)accessFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSString *currentFilePath, NSArray *filePaths))block {
    @synchronized(_currentFileLock) {
        @synchronized(_nonCurrentFilesLock) {
            return block(_manager, _currentFilePath, [self filePaths]);
        }
    }
}

- (BOOL)rotateFile {
    @synchronized(_currentFileLock) {
        @synchronized(_nonCurrentFilesLock) {
            if (![_manager isWritableFileAtPath:_currentFilePath]) {
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
            if (![_manager moveItemAtPath:_currentFilePath toPath:newFilePath error:&error]) {
                SFDebug(@"Could not rotate the current file \"%@\" to \"%@\" due to %@", _currentFilePath, newFilePath, [error localizedDescription]);
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileOperationErrors];
                return NO;
            }

            SFDebug(@"The current file is rotated to \"%@\"", newFilePath);
            return YES;
        }
    }
}

- (BOOL)removeDir {
    @synchronized(_currentFileLock) {
        @synchronized(_nonCurrentFilesLock) {
            [self closeCurrentFile];

            NSError *error;
            if (![_manager removeItemAtPath:_dirPath error:&error]) {
                SFDebug(@"Could not remove dir \"%@\" due to %@", _dirPath, [error localizedDescription]);
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileOperationErrors];
                return NO;
            }
            return YES;
        }
    }
}

// NOTE: You _must_ acquire respective locks before calling methods below.

- (NSFileHandle *)currentFile {
    if (!_currentFile) {
        SFDebug(@"Open the current file \"%@\"", _currentFilePath);

        if (![_manager isWritableFileAtPath:_currentFilePath]) {
            if (![_manager createFileAtPath:_currentFilePath contents:nil attributes:nil]) {
                SFDebug(@"Could not create \"%@\"", _currentFilePath);
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileOperationErrors];
                return nil;
            }
        }

        _currentFile = [NSFileHandle fileHandleForWritingAtPath:_currentFilePath];
        if (!_currentFile) {
            SFDebug(@"Could not open \"%@\" for writing", _currentFilePath);
            [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileOperationErrors];
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
    NSError *error;
    NSArray *fileNames = [_manager contentsOfDirectoryAtPath:_dirPath error:&error];
    if (!fileNames) {
        SFDebug(@"Could not list contents of directory \"%@\" due to %@", _dirPath, [error localizedDescription]);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileOperationErrors];
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
