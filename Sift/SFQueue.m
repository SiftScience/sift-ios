// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFQueue.h"

@implementation SFQueue {
    NSString *_identifier;
    NSMutableArray *_queue;
    SFQueueConfig _config;
    SFEvent *_lastEvent;
    SFTimestamp _lastEventTimestamp;
    NSString *_archivePath;
    // Weak reference back to the parent.
    Sift * __weak _sift;
}

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config archivePath:(NSString *)archivePath sift:(Sift *)sift {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _config = config;
        _archivePath = archivePath;
        _sift = sift;

        [self unarchive];

        // In case we just wake up from a long sleep...
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            if (self.readyForUpload) {
                [self requestUpload];
            } else {
                [self checkUploadReadinessLater];
            }
        });
    }
    return self;
}

- (void)append:(SFEvent *)event {
    @synchronized(self) {
        if (!event) {
            return;  // Don't append nil.
        }

        SFTimestamp now = SFCurrentTime();
        if (_config.appendEventOnlyWhenDifferent &&
            _lastEvent &&
            [_lastEvent isEssentiallyEqualTo:event] &&
            (!_config.acceptSameEventAfter || now - _lastEventTimestamp < _config.acceptSameEventAfter * 1000)) {
            SF_DEBUG(@"Drop the same event");
            return;  // Drop the same event as configured.
        }

        [_queue addObject:event];
        _lastEvent = event;
        _lastEventTimestamp = now;

        // Unfortunately iOS does not guarantee to always call you
        // before terminating your app and thus we have to persist data
        // aggressively when the app is in background.  Hopefully there
        // won't be too many events when app is in the background.
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                [self archive];
            });
        }

        if (self.readyForUpload) {
            [self requestUpload];
        } else {
            [self checkUploadReadinessLater];
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
static NSString * const SF_LAST_EVENT = @"lastEvent";
static NSString * const SF_LAST_EVENT_TIMESTAMP = @"lastEventTimestamp";

- (void)archive {
    @synchronized(self) {
        NSMutableDictionary *archive = [NSMutableDictionary new];
        [archive setObject:_queue forKey:SF_QUEUE];
        if (_lastEvent) {
            [archive setObject:_lastEvent forKey:SF_LAST_EVENT];
        }
        [archive setObject:@(_lastEventTimestamp) forKey:SF_LAST_EVENT_TIMESTAMP];
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

#pragma mark - Upload

- (BOOL)readyForUpload {
    if (_queue.count > _config.uploadWhenMoreThan) {
        SF_DEBUG(@"Too many events");
        return YES;
    }

    SFTimestamp age = SFCurrentTime() - _lastEventTimestamp;
    if (age > _config.uploadWhenOlderThan * 1000 && _queue.count > 0) {
        SF_DEBUG(@"Events get old");
        return YES;
    }

    return NO;
}

- (void)requestUpload {
    SF_DEBUG(@"Request upload");
    Sift *sift = _sift;
    if (sift) {
        if (![sift upload]) {
            SF_DEBUG(@"Upload request was rejected");
        }
    } else {
        SF_DEBUG(@"Reference to Sift object was lost");
    }
}

- (void)checkUploadReadinessLater {
    const SFTimestamp ERROR_MARGIN = 1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (_config.uploadWhenOlderThan + ERROR_MARGIN) * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        if (self.readyForUpload) {
            [self requestUpload];
        }
    });
}

@end
