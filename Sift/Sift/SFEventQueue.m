// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFile.h"

#import "SFEventQueue.h"
#import "SFEventQueue+Internal.h"

static NSDictionary *SFLastEvent(NSFileManager *manager, NSString *currentEventFilePath, NSArray *eventFilePaths);

@implementation SFEventQueue {
    NSString *_identifier;
    SFConfig _config;
    NSOperationQueue *_queue;
    SFEventFileManager *_manager;
    SFEventFileUploader *_uploader;
    NSDictionary *_lastEvent;
}

- (id)initWithIdentifier:(NSString *)identifier config:(SFConfig)config queue:(NSOperationQueue *)queue manager:(SFEventFileManager *)manager uploader:(SFEventFileUploader *)uploader {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _config = config;
        _queue = queue;
        _manager = manager;
        _uploader = uploader;
        _lastEvent = nil;
        if (![_manager addEventStore:_identifier]) {
            self = nil;
            return nil;
        }
        if (_config.rotateCurrentEventFileInterval > 0) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:_config.rotateCurrentEventFileInterval target:self selector:@selector(enqueueCheckOrRotateCurrentEventFile:) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        }
        if (_config.uploadEventFilesInterval > 0) {
            NSTimer *timer = [NSTimer timerWithTimeInterval:_config.uploadEventFilesInterval target:self selector:@selector(enqueueUploadEventFiles:) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        }
    }
    return self;
}

- (void)append:(NSDictionary *)event {
    [_queue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(appendEventInBackground:) object:event]];
}

- (void)enqueueCheckOrRotateCurrentEventFile:(NSTimer *)timer {
    [_queue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(checkOrRotateCurrentEventFile) object:nil]];
}

- (void)enqueueUploadEventFiles:(NSTimer *)timer {
    [_queue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(uploadEventFiles) object:nil]];
}

// NOTE: The following methods are only called in the background queue.

- (void)appendEventInBackground:(NSDictionary *)event {
    BOOL result;
    if (_config.trackEventDifferenceOnly) {
        result = [self appendEventIfDifferent:event lastEvent:_lastEvent];
        _lastEvent = event;
    } else {
        result = [self appendEvent:event];
    }
    if (!result) {
        NSLog(@"Could not append event to file and will drop it: %@", event);
        return;
    }

    // Rotate and upload synchronously if their respective interval <= 0.
    if (_config.rotateCurrentEventFileInterval <= 0) {
        [self checkOrRotateCurrentEventFile];
    }
    if (_config.uploadEventFilesInterval <= 0) {
        [self uploadEventFiles];
    }
}

- (BOOL)appendEventIfDifferent:(NSDictionary *)event lastEvent:(NSDictionary *)lastEvent {
    if (!lastEvent) {
        return [_manager useEventStore:_identifier withBlock:^BOOL (SFEventFileStore *store) {
            return [store accessAllEventFilesWithBlock:^BOOL (NSFileManager *manager, NSString *currentEventFilePath, NSArray *eventFilePaths) {
                NSDictionary *lastEvent = SFLastEvent(manager, currentEventFilePath, eventFilePaths);
                if (lastEvent) {
                    return [self appendEventIfDifferent:event lastEvent:lastEvent];
                } else {
                    return [self appendEvent:event];
                }
            }];
        }];
    } else if ([lastEvent isEqualToDictionary:event]) {
        return YES;
    } else {
        return [self appendEvent:event];
    }
}

- (BOOL)appendEvent:(NSDictionary *)event {
    return [_manager useEventStore:_identifier withBlock:^BOOL (SFEventFileStore *store) {
        return [store writeCurrentEventFileWithBlock:^BOOL (NSFileHandle *handle) {
            if (!SFEventFileAppendEvent(handle, event)) {
                // Remove it because the file might be corrupted or we are running out of space...
                [store removeCurrentEventFile];
                return NO;
            }
            return YES;
        }];
    }];
}

static NSDictionary *SFLastEvent(NSFileManager *manager, NSString *currentEventFilePath, NSArray *eventFilePaths) {
    if (currentEventFilePath && [manager isReadableFileAtPath:currentEventFilePath]) {
        return SFEventFileReadLastEvent([NSFileHandle fileHandleForReadingAtPath:currentEventFilePath]);
    }

    NSString *lastEventFilePath = nil;
    if (eventFilePaths && eventFilePaths.count > 0) {
        lastEventFilePath = [eventFilePaths lastObject];
    }
    if (lastEventFilePath && [manager isReadableFileAtPath:lastEventFilePath]) {
        return SFEventFileReadLastEvent([NSFileHandle fileHandleForReadingAtPath:[eventFilePaths lastObject]]);
    }

    return nil;
}

- (void)checkOrRotateCurrentEventFile {
    [_manager useEventStore:_identifier withBlock:^BOOL (SFEventFileStore *store) {
        return [store accessAllEventFilesWithBlock:^BOOL (NSFileManager *manager, NSString *currentEventFilePath, NSArray *eventFilePaths) {
            if (![self shouldRotateCurrentEventFile:currentEventFilePath manager:manager]) {
                return YES;
            }
            return [store rotateCurrentEventFile];
        }];
    }];
}

- (BOOL)shouldRotateCurrentEventFile:(NSString *)currentEventFilePath manager:(NSFileManager *)manager {
    if (![manager isWritableFileAtPath:currentEventFilePath]) {
        return NO;  // Nothing to rotate.
    }

    NSError *error;
    NSDictionary *attributes = [manager attributesOfItemAtPath:currentEventFilePath error:&error];
    if (!attributes) {
        NSLog(@"Could not get attributes of the current event file \"%@\" due to %@", currentEventFilePath, [error localizedDescription]);
        return NO;
    }

    if ([attributes fileSize] > _config.rotateCurrentEventFileIfLargerThan) {
        return YES;
    }

    NSTimeInterval sinceNow = -[[attributes fileModificationDate] timeIntervalSinceNow];
    if (sinceNow < 0) {
        NSLog(@"File modification date of \"%@\" is in the future: %@", currentEventFilePath, [attributes fileModificationDate]);
    } else if (sinceNow > _config.rotateCurrentEventFileIfOlderThan) {
        return YES;
    }

    return NO;
}

- (void)uploadEventFiles {
    [_manager useEventStore:_identifier withBlock:^BOOL (SFEventFileStore *store) {
        return [store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *paths) {
            if (!paths) {
                NSLog(@"The event file path array is nil (probably something went wrong)");
                return NO;
            }
            if (paths.count == 0) {
                return YES;
            }
            if (_config.trackEventDifferenceOnly) {
                // Upload one event file at a time if we track difference only.
                [_uploader upload:_identifier path:[paths objectAtIndex:0]];
            } else {
                for (NSString *path in paths) {
                    [_uploader upload:_identifier path:path];
                }
            }
            return YES;
        }];
    }];
}

@end