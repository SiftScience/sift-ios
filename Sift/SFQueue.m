// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent+Utils.h"
#import "SFMetrics.h"
#import "SFRecordIo.h"
#import "SFUtils.h"

#import "SFQueue.h"
#import "SFQueue+Private.h"

// NOTE: Make sure this does not conflict with SFRotatedFiles managed files.
static NSString * const SFQueueStateFileName = @"queue-state";

// TODO(clchiou): Make this part of SFQueueConfig.
static const NSInteger SFKeepLastState = 60 * 60 * 1000;

static BOOL SFRotateFile(NSString *identifier, SFRotatedFiles *rotatedFiles);

static NSDictionary *SFReadLastEvent(NSString *currentFilePath, NSArray *filePaths);

@implementation SFQueue {
    NSString *_identifier;
    NSString *_stateFilePath;
    SFQueueConfig _config;
    NSOperationQueue *_operationQueue;
    SFQueueDirs *_queueDirs;
    NSDictionary *_lastEvent;
    NSInteger _lastEventTimestamp;
}

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config operationQueue:(NSOperationQueue *)operationQueue queueDirs:(SFQueueDirs *)queueDirs {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _config = config;
        _operationQueue = operationQueue;
        _queueDirs = queueDirs;
        if (![_queueDirs addDir:_identifier]) {
            self = nil;
            return nil;
        }
        [_queueDirs useDir:_identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
            _stateFilePath = [rotatedFiles.dirPath stringByAppendingPathComponent:SFQueueStateFileName];
            return YES;
        }];
        // Currently, we only keep state for appendEventOnlyWhenDifferent queues.
        _lastEvent = nil;
        _lastEventTimestamp = 0;
        if (_config.appendEventOnlyWhenDifferent) {
            [self loadState];
        }
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(saveState) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)loadState {
    SF_DEBUG(@"Load _lastEvent");
    NSDictionary *state = SFFileExists(_stateFilePath) ? SFReadJsonFromFile(_stateFilePath) : nil;
    if (state) {
        _lastEvent = state[@"last_event"];
        _lastEventTimestamp = [state[@"last_event_timestamp"] integerValue];
    } else {
        // See if we could read the last event from data files...
        [_queueDirs useDir:_identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
            return [rotatedFiles accessFilesWithBlock:^BOOL (NSString *currentFilePath, NSArray *filePaths) {
                _lastEvent = SFReadLastEvent(currentFilePath, filePaths);
                if (_lastEvent) {
                    NSString *path = currentFilePath;
                    if (!path) {
                        path = [filePaths lastObject];
                    }
                    if (!path || !SFFileModificationTimestamp(path, &_lastEventTimestamp)) {
                        SF_DEBUG(@"Could not read last modification date from data files");
                        _lastEvent = nil;
                        _lastEventTimestamp = 0;
                    }
                }
                return _lastEvent ? YES : NO;
            }];
        }];
    }
}

- (void)saveState {
    if (_lastEvent) {
        SF_DEBUG(@"Save _lastEvent");
        SFWriteJsonToFile(@{@"last_event": _lastEvent, @"last_event_timestamp": [NSNumber numberWithInteger:_lastEventTimestamp]}, _stateFilePath);
    }
}

- (void)append:(NSDictionary *)event {
    [_operationQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(maybeWriteEventToFile:) object:event]];
}

// NOTE: The following methods are only called in the background queue.

- (void)maybeWriteEventToFile:(NSDictionary *)event {
    BOOL result;
    if (_config.appendEventOnlyWhenDifferent) {
        NSInteger now = SFTimestampMillis();
        SF_DEBUG(@"lastEventTimestamp=%ld now=%ld", _lastEventTimestamp, now);
        if (_lastEventTimestamp + SFKeepLastState < now) {
            SF_DEBUG(@"discard lastEvent");
            _lastEvent = nil;
            _lastEventTimestamp = 0;
        }
        if (_lastEvent && SFEventCompare(_lastEvent, event)) {
            SF_DEBUG(@"Ignore same event");
            result = YES;
        } else {
            result = [self writeEventToFile:event];
        }
        _lastEvent = event;
        _lastEventTimestamp = SFTimestampMillis();
    } else {
        result = [self writeEventToFile:event];
    }
    if (!result) {
        SF_DEBUG(@"Could not append event to file and will drop it: %@", event);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumEventsDropped];
        return;
    }
    [self maybeRotateFile];
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

- (BOOL)rotateFile {
    return [_queueDirs useDir:_identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles accessFilesWithBlock:^BOOL (NSString *currentFilePath, NSArray *filePaths) {
            return SFRotateFile(_identifier, rotatedFiles);
        }];
    }];
}

- (BOOL)maybeRotateFile {
    return [_queueDirs useDir:_identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles accessFilesWithBlock:^BOOL (NSString *currentFilePath, NSArray *filePaths) {
            if (_config.appendEventOnlyWhenDifferent && filePaths && filePaths.count > 0) {
                SF_DEBUG(@"Would rather not rotate files of queue %@ for maintaining strict upload order", _identifier);
                return YES;
            }
            if (!SFQueueShouldRotateFile(currentFilePath, &_config)) {
                SF_DEBUG(@"Would rather not rotate files of queue %@", _identifier);
                return YES;
            }
            return SFRotateFile(_identifier, rotatedFiles);
        }];
    }];
}

BOOL SFQueueShouldRotateFile(NSString *currentFilePath, SFQueueConfig *config) {
    NSFileManager *manager = [NSFileManager defaultManager];

    if (![manager isWritableFileAtPath:currentFilePath]) {
        return NO;  // Nothing to rotate.
    }

    NSDictionary *attributes = SFFileAttrs(currentFilePath);
    if (!attributes) {
        return NO;
    }

    unsigned long long fileSize = [attributes fileSize];
    if (fileSize > config->rotateWhenLargerThan) {
        SF_DEBUG(@"Should rotate file due to file size: %lld > %ld", fileSize, (long)config->rotateWhenLargerThan);
        return YES;
    }

    NSTimeInterval sinceNow = -[[attributes fileModificationDate] timeIntervalSinceNow];
    if (sinceNow < 0) {
        SF_DEBUG(@"File modification date of \"%@\" is in the future: %@", currentFilePath, [attributes fileModificationDate]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
    } else if (sinceNow > config->rotateWhenOlderThan) {
        SF_DEBUG(@"Should rotate file due to modification date: %.2f > %.2f", sinceNow, config->rotateWhenOlderThan);
        return YES;
    }

    return NO;
}

@end

static BOOL SFRotateFile(NSString *identifier, SFRotatedFiles *rotatedFiles) {
    BOOL okay = [rotatedFiles rotateFile];
    if (okay) {
        SF_DEBUG(@"Files were rotated for queue %@", identifier);
    }
    return okay;
}

static NSDictionary *SFReadLastEvent(NSString *currentFilePath, NSArray *filePaths) {
    NSString *filePath = nil;
    if (currentFilePath) {
        filePath = currentFilePath;
    } else if (filePaths && filePaths.count > 0) {
        filePath = [filePaths lastObject];
    }
    return filePath ? SFRecordIoReadLastRecord([NSFileHandle fileHandleForReadingAtPath:filePath]) : nil;
}
