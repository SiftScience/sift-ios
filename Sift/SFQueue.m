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
    SFTimestamp _lastUploadTimestamp;
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
    }
    return self;
}

- (void)append:(SFEvent *)event {
    @synchronized(self) {
        if (!event) {
            return;  // Don't append nil.
        }

        SFTimestamp now = SFCurrentTime();
        if (_config.acceptSameEventAfter > 0 &&
            _lastEvent &&
            (now < _lastEvent.time + _config.acceptSameEventAfter * 1000) &&
            [_lastEvent isEssentiallyEqualTo:event]) {
            SF_DEBUG(@"Drop the same event");
            return;  // Drop the same event as configured.
        }

        SF_DEBUG(@"Appending event");
        [_queue addObject:event];
        _lastEvent = event;
        
        // Unfortunately iOS does not guarantee to always call you
        // before terminating your app and thus we have to persist data
        // aggressively when the app is in background.  Hopefully there
        // won't be too many events when app is in the background.
        dispatch_async(dispatch_get_main_queue(), ^{
            if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
                    [self archive];
                });
            }
        });
        
        if (self.readyForUpload) {
            [self requestUpload];
            _lastUploadTimestamp = SFCurrentTime();
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
static NSString * const SF_LAST_UPLOAD_TIMESTAMP = @"lastUploadTimestamp";

- (void)archive {
    @synchronized(self) {
        NSMutableDictionary *archive = [NSMutableDictionary new];
        [archive setObject:_queue forKey:SF_QUEUE];
        if (_lastEvent) {
            [archive setObject:_lastEvent forKey:SF_LAST_EVENT];
        }
        [archive setObject:@(_lastUploadTimestamp) forKey:SF_LAST_UPLOAD_TIMESTAMP];
        [NSKeyedArchiver archiveRootObject:archive toFile:_archivePath];
    }
}

- (void)unarchive {
    @synchronized(self) {
        NSDictionary *archive = [NSKeyedUnarchiver unarchiveObjectWithFile:_archivePath];
        if (archive) {
            _queue = [NSMutableArray arrayWithArray:[archive objectForKey:SF_QUEUE]];
            _lastEvent = [archive objectForKey:SF_LAST_EVENT];
            _lastUploadTimestamp = [[archive objectForKey:SF_LAST_UPLOAD_TIMESTAMP] unsignedLongLongValue];
        } else {
            _queue = [NSMutableArray new];
            _lastEvent = nil;
            _lastUploadTimestamp = 0;
        }
        SF_DEBUG(@"Unarchive: _lastUploadTimestamp=%llu", _lastUploadTimestamp);
    }
}

#pragma mark - Upload

- (BOOL)readyForUpload {
    if (_config.uploadWhenMoreThan >= 0 &&
        _queue.count > _config.uploadWhenMoreThan) {
        SF_DEBUG(@"Queue is full");
        return YES;
    }
    
    SFTimestamp now = SFCurrentTime();
    
    if (_config.uploadWhenOlderThan > 0 &&
        _queue.count > 0 &&
        now > _lastUploadTimestamp + _config.uploadWhenOlderThan * 1000) {
        SF_DEBUG(@"Queue is old");
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
        } else {
            SF_DEBUG(@"Upload successful");
        }
    } else {
        SF_DEBUG(@"Reference to Sift object was lost");
    }
}

@end
