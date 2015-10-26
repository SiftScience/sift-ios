// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFMetrics.h"
#import "SFRecordIo.h"
#import "SFUtil.h"

#import "SFQueue.h"
#import "SFQueue+Private.h"

static NSDictionary *SFReadLastEvent(NSFileManager *manager, NSString *currentFilePath, NSArray *filePaths);

@implementation SFQueue {
    NSString *_identifier;
    SFQueueConfig _config;
    NSOperationQueue *_operationQueue;
    SFQueueDirs *_queueDirs;
    NSDictionary *_lastEvent;
}

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config operationQueue:(NSOperationQueue *)operationQueue queueDirs:(SFQueueDirs *)queueDirs {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _config = config;
        _operationQueue = operationQueue;
        _queueDirs = queueDirs;
        _lastEvent = nil;
        if (![_queueDirs addDir:_identifier]) {
            self = nil;
            return nil;
        }
    }
    return self;
}

- (void)append:(NSDictionary *)event {
    [[SFMetrics sharedMetrics] count:SFMetricsKeyQueueAppend];
    [_operationQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(maybeWriteEventToFile:) object:event]];
}

// NOTE: The following methods are only called in the background queue.

- (void)maybeWriteEventToFile:(NSDictionary *)event {
    BOOL result;
    if (_config.appendEventOnlyWhenDifferent) {
        result = [self writeEventToFileWhenDifferent:event lastEvent:_lastEvent];
        _lastEvent = event;
    } else {
        result = [self writeEventToFile:event];
    }
    if (!result) {
        SFDebug(@"Could not append event to file and will drop it: %@", event);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyQueueNumEventsDropped];
        return;
    }
    [self maybeRotateFile];
}

- (BOOL)writeEventToFileWhenDifferent:(NSDictionary *)event lastEvent:(NSDictionary *)lastEvent {
    if (!lastEvent) {
        return [_queueDirs useDir:_identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
            return [rotatedFiles accessFilesWithBlock:^BOOL (NSFileManager *manager, NSString *currentFilePath, NSArray *filePaths) {
                NSDictionary *lastEvent = SFReadLastEvent(manager, currentFilePath, filePaths);
                if (lastEvent) {
                    return [self writeEventToFileWhenDifferent:event lastEvent:lastEvent];
                } else {
                    return [self writeEventToFile:event];
                }
            }];
        }];
    } else if ([lastEvent isEqualToDictionary:event]) {
        return YES;
    } else {
        return [self writeEventToFile:event];
    }
}

- (BOOL)writeEventToFile:(NSDictionary *)event {
    return [_queueDirs useDir:_identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles writeCurrentFileWithBlock:^BOOL (NSFileHandle *handle) {
            if (!SFRecordIoAppendRecord(handle, event)) {
                // Remove it because the file might be corrupted or we are running out of space...
                [rotatedFiles removeCurrentFile];
                return NO;
            }
            return YES;
        }];
    }];
}

- (void)maybeRotateFile {
    BOOL rotated = [_queueDirs useDir:_identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles accessFilesWithBlock:^BOOL (NSFileManager *manager, NSString *currentFilePath, NSArray *filePaths) {
            if (_config.appendEventOnlyWhenDifferent && filePaths && filePaths.count > 0) {
                return NO;  // Maintain strict upload order...
            }
            if (!SFQueueShouldRotateFile(manager, currentFilePath, &_config)) {
                return NO;
            }
            return [rotatedFiles rotateFile];
        }];
    }];
    SFDebug(@"%s: files %s rotated", __func__, rotated ? "were" : "weren't");
}

BOOL SFQueueShouldRotateFile(NSFileManager *manager, NSString *currentFilePath, SFQueueConfig *config) {
    if (![manager isWritableFileAtPath:currentFilePath]) {
        return NO;  // Nothing to rotate.
    }

    NSError *error;
    NSDictionary *attributes = [manager attributesOfItemAtPath:currentFilePath error:&error];
    if (!attributes) {
        SFDebug(@"Could not get attributes of the current file \"%@\" due to %@", currentFilePath, [error localizedDescription]);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyQueueFileAttributesRetrievalError];
        return NO;
    }

    unsigned long long fileSize = [attributes fileSize];
    if (fileSize > config->uploadEventsWhenLargerThan) {
        SFDebug(@"Should rotate file due to file size: %lld > %ld", fileSize, config->uploadEventsWhenLargerThan);
        return YES;
    }

    NSTimeInterval sinceNow = -[[attributes fileModificationDate] timeIntervalSinceNow];
    if (sinceNow < 0) {
        SFDebug(@"File modification date of \"%@\" is in the future: %@", currentFilePath, [attributes fileModificationDate]);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyQueueFutureFileModificationDate];
    } else if (sinceNow > config->uploadEventsWhenOlderThan) {
        SFDebug(@"Should rotate file due to modification date: %.2f > %.2f", sinceNow, config->uploadEventsWhenOlderThan);
        return YES;
    }

    return NO;
}

static NSDictionary *SFReadLastEvent(NSFileManager *manager, NSString *currentFilePath, NSArray *filePaths) {
    NSString *filePath = nil;
    if (currentFilePath) {
        filePath = currentFilePath;
    } else if (filePaths && filePaths.count > 0) {
        filePath = [filePaths lastObject];
    }
    return filePath ? SFRecordIoReadLastRecord([NSFileHandle fileHandleForReadingAtPath:filePath]) : nil;
}

@end
