// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFUtils.h"

#import "SFQueue.h"

@implementation SFQueue {
    NSString *_identifier;
    NSMutableArray *_queue;
    SFQueueConfig _config;
    SFEvent *_lastEvent;
    SFTimestamp _lastEventTimestamp;
    NSString *_archivePath;
}

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config archivePath:(NSString *)archivePath {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _config = config;
        _archivePath = archivePath;
        [self unarchive];
    }
    return self;
}

- (void)append:(SFEvent *)event {
    @synchronized(self) {
        if (!event) {
            return;  // Don't append nil.
        }
        if (_config.appendEventOnlyWhenDifferent && _lastEvent && [_lastEvent isEssentiallyEqualTo:event]) {
            return;  // Drop the same event as configured.
        }
        [_queue addObject:event];
        _lastEvent = event;
        _lastEventTimestamp = SFCurrentTime();

        // Unfortunately iOS does not guarantee to always call you
        // before terminating your app and thus we have to persist data
        // aggressively when the app is in background.  Hopefully there
        // won't be too many events when app is in the background.
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                [self archive];
            });
        }
    }
}

- (NSArray *)transfer {
    @synchronized(self) {
        NSArray *queue = _queue;
        _queue = [NSMutableArray new];
        return queue;
    }
}

#pragma mark - NSKeyedArchiver/NSKeyedUnarchiver

// Keys for archive.
static NSString * const SF_QUEUE = @"queue";
static NSString * const SF_LAST_EVENT = @"last_event";
static NSString * const SF_LAST_EVENT_TIMESTAMP = @"lastEventTimestamp";

- (void)archive {
    @synchronized(self) {
        NSDictionary *archive = @{SF_QUEUE: _queue,
                                  SF_LAST_EVENT: _lastEvent,
                                  SF_LAST_EVENT_TIMESTAMP: @(_lastEventTimestamp)};
        [NSKeyedArchiver archiveRootObject:archive toFile:_archivePath];
    }
}

- (void)unarchive {
    @synchronized(self) {
        NSDictionary *archive = [NSKeyedUnarchiver unarchiveObjectWithFile:_archivePath];
        if (archive) {
            _queue = [NSMutableArray arrayWithArray:[archive objectForKey:SF_QUEUE]];
            _lastEvent = [archive objectForKey:SF_LAST_EVENT];
            NSNumber *last = [archive objectForKey:SF_LAST_EVENT_TIMESTAMP];
            _lastEventTimestamp = last.unsignedLongLongValue;
        } else {
            _queue = [NSMutableArray new];
            _lastEvent = nil;
            _lastEventTimestamp = 0;
        }
        SF_DEBUG(@"Unarchive: _lastEventTimestamp=%llu", _lastEventTimestamp);
    }
}

- (void)removeData {
    @synchronized(self) {
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtPath:_archivePath error:&error]) {
            SF_DEBUG(@"Could not remove queue archive \"%@\" due to %@", _archivePath, [error localizedDescription]);
        }
    }
}

@end
