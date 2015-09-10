// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventsFileManager.h"
#import "SFEventsFileManagerInternal.h"

NSString *EVENTS_FILE_NAME = @"events";
NSString *EVENTS_FILE_PATTERN = @"^events-(\\d+)$";

// Rotate the current events file when it grows larger than 1024 bytes.
const unsigned long long EVENTS_FILE_SIZE_LIMIT = 1024;

// Rotate the current events file if it is older than 30 seconds.
const NSTimeInterval EVENTS_FILE_LAST_MODIFICATION_LIMIT = 30;

@implementation SFEventsFileManager {
    NSFileManager *_manager;

    NSString *_eventsDirPath;
    NSRegularExpression *_eventsFileRegex;

    NSString *_currentEventsFilePath;
    NSFileHandle *_currentEventsFile;

    // Acquire locks in the following order:
    id _currentEventsFileLock;
    id _eventsFilesLock;
}

+ (SFEventsFileManager *)sharedInstance {
    static SFEventsFileManager *manager = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        manager = [[SFEventsFileManager alloc] initWithEventsDirName:@"data"];
    });
    return manager;
}

- (id)initWithEventsDirName:(NSString *)eventsDirName  {
    self = [super init];
    if (self) {
        _manager = [NSFileManager defaultManager];

        NSString *cachesDirPath = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        _eventsDirPath = [cachesDirPath stringByAppendingPathComponent:eventsDirName];
        NSError *error;
        _eventsFileRegex = [NSRegularExpression regularExpressionWithPattern:EVENTS_FILE_PATTERN options:0 error:&error];
        if (error) {
            [NSException raise:@"RegexException" format:@"Could not construct regex due to %@", [error localizedDescription]];
        }

        _currentEventsFilePath = [_eventsDirPath stringByAppendingPathComponent:EVENTS_FILE_NAME];
        _currentEventsFile = nil;
        
        _currentEventsFileLock = [NSObject new];
        _eventsFilesLock = [NSObject new];
    }
    return self;
}

- (NSFileManager *)manager {
    return _manager;
}

- (NSString *)eventsDirPath {
    return _eventsDirPath;
}

- (void)removeEventsDir {
    @synchronized(_currentEventsFileLock) {
        @synchronized(_eventsFilesLock) {
            NSError *error;
            if (![_manager removeItemAtPath:_eventsDirPath error:&error]) {
                NSLog(@"Could not remove directory \"%@\" due to %@", _eventsDirPath, [error localizedDescription]);
            }
        }
    }
}

- (void)processEventsFiles:(void (^)(NSFileManager *, NSArray *))reader {
    @synchronized(_eventsFilesLock) {
        reader(_manager, [self listEventsFilePathsNeedLocking]);
    }
}

- (NSArray *)listEventsFilePathsNeedLocking {
    [self createEventsDirNeedLocking];
    
    NSError *error;
    NSArray *fileNames = [_manager contentsOfDirectoryAtPath:_eventsDirPath error:&error];
    if (!fileNames) {
        [NSException raise:@"DirectoryException" format:@"Could not list contents of directory \"%@\" due to %@", _eventsDirPath, [error localizedDescription]];
    }

    NSPredicate *eventsFilePathPredicate = [NSPredicate predicateWithBlock:^BOOL(id fileName, NSDictionary *bindings) {
        return [_eventsFileRegex numberOfMatchesInString:fileName options:0 range:NSMakeRange(0, [fileName length])] > 0;
    }];
    fileNames = [[fileNames filteredArrayUsingPredicate:eventsFilePathPredicate] sortedArrayUsingSelector:@selector(compare:)];

    NSMutableArray *paths = [NSMutableArray arrayWithCapacity:fileNames.count];
    for (NSString *fileName in fileNames) {
        [paths addObject:[_eventsDirPath stringByAppendingPathComponent:fileName]];
    }
    return paths;
}

- (void)writeCurrentEventsFile:(void (^)(NSFileHandle *))writer {
    @synchronized(_currentEventsFileLock) {
        // Create the current events file on-demand.
        if (!_currentEventsFile) {
            [self createCurrentEventsFileNeedLocking];
        }
        writer(_currentEventsFile);
    }
}

- (void)createEventsDirNeedLocking {
    BOOL isDirectory = NO;
    if ([_manager fileExistsAtPath:_eventsDirPath isDirectory:&isDirectory]) {
        if (!isDirectory) {
            [NSException raise:@"RuntimeError" format:@"File already exists \"%@\"", _eventsDirPath];
        }
    } else {
        NSError *error;
        if (![_manager createDirectoryAtPath:_eventsDirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            [NSException raise:@"DirCreationException" format:@"Could not create directory \"%@\" due to %@", _eventsDirPath, [error localizedDescription]];
        }
    }
}

- (void)createCurrentEventsFileNeedLocking {
    if (_currentEventsFile) {
        [NSException raise:@"FileHandleExistException" format:@"Could not overwrite file handle for \"%@\"", _currentEventsFilePath];
    }

    NSLog(@"Open \"%@\" for appending events", _currentEventsFilePath);

    [self createEventsDirNeedLocking];

    if (![_manager isWritableFileAtPath:_currentEventsFilePath]) {
        NSLog(@"Create the current event file \"%@\"", _currentEventsFilePath);
        if (![_manager createFileAtPath:_currentEventsFilePath contents:nil attributes:nil]) {
            [NSException raise:@"FileCreationException" format:@"Could not create \"%@\"", _currentEventsFilePath];
        }
    }

    _currentEventsFile = [NSFileHandle fileHandleForWritingAtPath:_currentEventsFilePath];
    if (!_currentEventsFile) {
        [NSException raise:@"FileNotFoundException" format:@"Could not open \"%@\" for writing", _currentEventsFilePath];
    }
    [_currentEventsFile seekToEndOfFile];
}

- (BOOL)maybeRotateCurrentEventsFile:(BOOL)forceRotating {
    @synchronized(_currentEventsFileLock) {
        @synchronized(_eventsFilesLock) {
            if (forceRotating || [self shouldRotateCurrentEventsFileNeedLocking]) {
                [self rotateCurrentEventsFileNeedLocking];
                return YES;
            } else {
                return NO;
            }
        }
    }
}

- (BOOL)shouldRotateCurrentEventsFileNeedLocking {
    if (!_currentEventsFile) {
        return NO;
    }

    NSError *error;
    NSDictionary *attributes = [_manager attributesOfItemAtPath:_currentEventsFilePath error:&error];
    if (!attributes) {
        NSLog(@"Could not get attributes of the current events file \"%@\" due to %@", _currentEventsFilePath, [error localizedDescription]);
        return NO;
    } else if ([attributes fileSize] >= EVENTS_FILE_SIZE_LIMIT) {
        return YES;
    } else if ([attributes fileModificationDate].timeIntervalSinceNow >= EVENTS_FILE_LAST_MODIFICATION_LIMIT) {
        return YES;
    } else {
        return NO;
    }
}

- (void)rotateCurrentEventsFileNeedLocking {
    if (!_currentEventsFile) {
        return;
    }
    
    NSLog(@"Rotate the current events file");
    
    [_currentEventsFile closeFile];
    _currentEventsFile = nil;
    
    NSString *eventsFilePath = [self findNextEventsFilePathNeedLocking];
    if (!eventsFilePath) {
        return;
    }
    
    NSError *error;
    if (![_manager moveItemAtPath:_currentEventsFilePath toPath:eventsFilePath error:&error]) {
        NSLog(@"Could not rotate the current events file \"%@\" to \"%@\" due to %@", _currentEventsFilePath, eventsFilePath, [error localizedDescription]);
        return;
    }
    
    NSLog(@"The current events file is rotated to \"%@\"", eventsFilePath);
}

- (NSString *)findNextEventsFilePathNeedLocking {
    NSError *error;
    NSArray *paths = [_manager contentsOfDirectoryAtPath:_eventsDirPath error:&error];
    if (!paths) {
        NSLog(@"Could not list contents of directory \"%@\" due to %@", _eventsDirPath, [error localizedDescription]);
        return nil;
    }

    int largestEventsFileIndex = 0;
    for (NSString *path in paths) {
        NSString *fileName = [path lastPathComponent];
        NSTextCheckingResult *match = [_eventsFileRegex firstMatchInString:fileName options:0 range:NSMakeRange(0, fileName.length)];
        if (match) {
            int eventsFileIndex = [fileName substringWithRange:[match rangeAtIndex:1]].intValue;
            if (eventsFileIndex > largestEventsFileIndex) {
                largestEventsFileIndex = eventsFileIndex;
            }
        }
    }

    return [_eventsDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@-%d", EVENTS_FILE_NAME, largestEventsFileIndex + 1]];
}

@end