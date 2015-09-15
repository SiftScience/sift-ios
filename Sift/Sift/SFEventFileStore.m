// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileStore.h"
#import "SFEventFileStore+Internal.h"

static NSString *EVENT_FILE_NAME = @"events";
static NSString *EVENT_FILE_PATTERN = @"^events-(\\d+)$";

@implementation SFEventFileStore {
    NSString *_eventDirPath;
    NSString *_currentEventFilePath;

    // Cache the opened file handle so that we don't have to open it every time.
    NSFileHandle *_currentEventFile;

    NSRegularExpression *_eventFileNameRegex;

    NSFileManager *_manager;

    // Acquire these locks by the declaration order.
    NSObject *_currentEventFileLock;
    NSObject *_eventFilesLock;
}

- (id)initWithEventDirPath:(NSString *)eventDirPath {
    self = [super init];
    if (self) {
        NSError *error;

        _eventDirPath = eventDirPath;
        _currentEventFilePath = [_eventDirPath stringByAppendingPathComponent:EVENT_FILE_NAME];

        _currentEventFile = nil;

        _eventFileNameRegex = [NSRegularExpression regularExpressionWithPattern:EVENT_FILE_PATTERN options:0 error:&error];
        if (error) {
            NSLog(@"Could not construct regex due to %@", [error localizedDescription]);
            self = nil;
            return nil;
        }

        _manager = [NSFileManager defaultManager];

        NSLog(@"Create event dir \"%@\"", _eventDirPath);
        if (![_manager createDirectoryAtPath:_eventDirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Could not create event dir \"%@\" due to %@", _eventDirPath, [error localizedDescription]);
            self = nil;
            return nil;
        }

        _currentEventFileLock = [NSObject new];
        _eventFilesLock = [NSObject new];
    }
    return self;
}

- (BOOL)writeCurrentEventFileWithBlock:(BOOL (^)(NSFileHandle *))block {
    @synchronized(_currentEventFileLock) {
        return block([self currentEventFile]);
    }
}

- (void)removeCurrentEventFile {
    @synchronized(_currentEventFileLock) {
        [self closeCurrentEventFile];

        NSError *error;
        if (![_manager removeItemAtPath:_currentEventFilePath error:&error]) {
            NSLog(@"Could not remove the current event file \"%@\" due to %@", _currentEventFilePath, [error localizedDescription]);
        }
    }
}

- (BOOL)accessEventFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSArray *eventFilePaths))block {
    @synchronized(_eventFilesLock) {
        return block(_manager, [self eventFilePaths]);
    }
}

- (BOOL)accessAllEventFilesWithBlock:(BOOL (^)(NSFileManager *manager, NSString *currentEventFilePath, NSArray *eventFilePaths))block {
    @synchronized(_currentEventFileLock) {
        @synchronized(_eventFilesLock) {
            return block(_manager, _currentEventFilePath, [self eventFilePaths]);
        }
    }
}

- (BOOL)rotateCurrentEventFile {
    @synchronized(_currentEventFileLock) {
        @synchronized(_eventFilesLock) {
            if (![_manager isWritableFileAtPath:_currentEventFilePath]) {
                return YES;   // Nothing to rotate...
            }

            NSArray *eventFilePaths = [self eventFilePaths];
            if (!eventFilePaths) {
                return NO;
            }
            
            int largestIndex = -1;
            if (eventFilePaths.count > 0) {
                largestIndex = [self eventFileIndex:[[eventFilePaths lastObject] lastPathComponent]];
            }
            NSString *newEventFileName = [NSString stringWithFormat:@"%@-%d", EVENT_FILE_NAME, (largestIndex + 1)];
            NSString *newEventFilePath = [_eventDirPath stringByAppendingPathComponent:newEventFileName];
            
            // Close the current event file handle before rotating it.
            [self closeCurrentEventFile];
            
            NSError *error;
            if (![_manager moveItemAtPath:_currentEventFilePath toPath:newEventFilePath error:&error]) {
                NSLog(@"Could not rotate the current event file \"%@\" to \"%@\" due to %@", _currentEventFilePath, newEventFilePath, [error localizedDescription]);
                return NO;
            }
            
            NSLog(@"The current event file is rotated to \"%@\"", newEventFilePath);
            return YES;
        }
    }
}

- (BOOL)removeEventDir {
    @synchronized(_currentEventFileLock) {
        @synchronized(_eventFilesLock) {
            [self closeCurrentEventFile];

            NSError *error;
            if (![_manager removeItemAtPath:_eventDirPath error:&error]) {
                NSLog(@"Could not remove event dir \"%@\" due to %@", _eventDirPath, [error localizedDescription]);
                return NO;
            }
            return YES;
        }
    }
}

// NOTE: You _must_ acquire respective locks before calling methods below.

- (NSFileHandle *)currentEventFile {
    if (!_currentEventFile) {
        NSLog(@"Open the current event file \"%@\"", _currentEventFilePath);

        if (![_manager isWritableFileAtPath:_currentEventFilePath]) {
            if (![_manager createFileAtPath:_currentEventFilePath contents:nil attributes:nil]) {
                NSLog(@"Could not create \"%@\"", _currentEventFilePath);
                return nil;
            }
        }

        _currentEventFile = [NSFileHandle fileHandleForWritingAtPath:_currentEventFilePath];
        if (!_currentEventFile) {
            NSLog(@"Could not open \"%@\" for writing", _currentEventFilePath);
            return nil;
        }

        [_currentEventFile seekToEndOfFile];
    }
    return _currentEventFile;
}

- (void)closeCurrentEventFile {
    if (_currentEventFile) {
        [_currentEventFile closeFile];
        _currentEventFile = nil;
    }
}

- (NSArray *)eventFilePaths {
    NSError *error;
    NSArray *fileNames = [_manager contentsOfDirectoryAtPath:_eventDirPath error:&error];
    if (!fileNames) {
        NSLog(@"Could not list contents of directory \"%@\" due to %@", _eventDirPath, [error localizedDescription]);
        return nil;
    }

    fileNames = [fileNames filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id fileName, NSDictionary *bindings) {
        return [self eventFileIndex:fileName] >= 0;
    }]];

    // Sort file names by the event file index (_not_ by alphabetic order).
    fileNames = [fileNames sortedArrayUsingComparator:^NSComparisonResult(NSString *fileName1, NSString *fileName2) {
        return [self eventFileIndex:fileName1] - [self eventFileIndex:fileName2];
    }];

    NSMutableArray *paths = [NSMutableArray arrayWithCapacity:fileNames.count];
    for (NSString *fileName in fileNames) {
        [paths addObject:[_eventDirPath stringByAppendingPathComponent:fileName]];
    }
    return paths;
}

- (int)eventFileIndex:(NSString *)eventFileName {
    NSTextCheckingResult *match = [_eventFileNameRegex firstMatchInString:eventFileName options:0 range:NSMakeRange(0, eventFileName.length)];
    if (!match) {
        return -1;
    }
    NSString *number = [eventFileName substringWithRange:[match rangeAtIndex:1]];
    return number.intValue;
}

@end
