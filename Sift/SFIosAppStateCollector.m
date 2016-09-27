// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"
#import "SFIosAppState.h"
#import "SFTokenBucket.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFIosAppStateCollector.h"

// We rate limit to no more than 30 collections in 1 minute.
static const double         SF_COLLECTION_RATE_LIMIT_NUM_COLLECTIONS = 30;
static const NSTimeInterval SF_COLLECTION_RATE_LIMIT_PERIOD = 60; // Unit: second.

// If there was no collection in the last 2 minutes, request a collection.
static const SFTimestamp SF_MAX_COLLECTION_PERIOD = 120000;  // Unit: millisecond.

@interface SFIosAppStateCollector ()

/** Load archived data. */
- (void)unarchive;

/**
 * Request to collect app state.
 *
 * The request might be ignored due to rate limiting.
 */
- (void)requestCollection;

/**
 * Collect app state if there was no collection in the last SF_MAX_COLLECTION_PERIOD of time and app is active.
 */
- (void)checkAndCollectWhenNoneRecently:(SFTimestamp)now;

/** Collect app state. */
- (void)collect:(SFTimestamp)now;

@end

@implementation SFIosAppStateCollector {
    // Use serial queue as an alternative to locking.
    dispatch_queue_t _serial;
    dispatch_source_t _source;
    NSString *_archivePath;
    CLLocationManager *_locationManager;

    //// Archived states.

    SFTokenBucket *_bucket;  // Control the rate of requestCollection.
    SFTimestamp _lastCollectedAt;  // Control the rate of checkAndCollectWhenNoneRecently.
}

- (instancetype)initWithArchivePath:(NSString *)archivePath {
    self = [super init];
    if (self) {
        _serial = dispatch_queue_create("com.sift.SFIosAppStateCollector", DISPATCH_QUEUE_SERIAL);
        _archivePath = archivePath;
        _locationManager = [CLLocationManager new];

        [self unarchive];

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];

        // Observe root view controller's title changes.
        NSString *rootViewControllerKeyPath = NSStringFromSelector(@selector(rootViewController));
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            [window addObserver:self forKeyPath:rootViewControllerKeyPath options:0 context:nil];
        }

        // Also check periodically.
        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _serial);
        dispatch_source_set_timer(_source, dispatch_time(DISPATCH_TIME_NOW, 0), SF_MAX_COLLECTION_PERIOD * NSEC_PER_MSEC, 10 * NSEC_PER_SEC);
        SFIosAppStateCollector * __weak weakSelf = self;
        dispatch_source_set_event_handler(_source, ^{
            [weakSelf checkAndCollectWhenNoneRecently:SFCurrentTime()];
        });
        dispatch_resume(_source);
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *, id> *)change context:(void *)context {
    SF_DEBUG(@"Notified with KVO change: %@.%@", ((NSObject *)object).class, keyPath);
    [self requestCollection];
}

- (void)willEnterForeground {
    dispatch_resume(_serial);
    [self requestCollection];
}

- (void)didEnterBackground {
    [self requestCollection];
    // Suspend after requestCollection's block is executed.
    dispatch_async(_serial, ^{
        dispatch_suspend(_serial);
    });
}

- (void)requestCollection {
    // We don't care whether the remaining requests are executed if we are gone.
    SFIosAppStateCollector * __weak weakSelf = self;
    dispatch_async(_serial, ^{
        SFIosAppStateCollector *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (![_bucket tryAcquire]) {
            SF_DEBUG(@"Ignore collection request due to rate limit");
            return;
        }

        [strongSelf collect:SFCurrentTime()];
    });
}

- (void)checkAndCollectWhenNoneRecently:(SFTimestamp)now {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        SF_DEBUG(@"Ignore collection request since the app is not active");
        return;
    }

    if (_lastCollectedAt > 0) {
        if (_lastCollectedAt + SF_MAX_COLLECTION_PERIOD >= now) {
            SF_DEBUG(@"Ignore collection request since it is not long enough since last collection");
            return;
        }
    }

    [self collect:now];
}

- (void)collect:(SFTimestamp)now {
    SF_DEBUG(@"Collect app state...");
    SFEvent *event = [SFEvent new];
    event.time = now;
    event.iosAppState = SFCollectIosAppState(_locationManager);
    [Sift.sharedInstance appendEvent:event];

    _lastCollectedAt = now;

    // We don't care whether the remaining requests are executed if we are gone.
    SFIosAppStateCollector * __weak weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, SF_MAX_COLLECTION_PERIOD * NSEC_PER_MSEC), _serial, ^{
        [weakSelf checkAndCollectWhenNoneRecently:SFCurrentTime()];
    });
}

#pragma mark - NSKeyedArchiver/NSKeyedUnarchiver

static NSString * const SF_BUCKET = @"bucket";
static NSString * const SF_LAST_COLLECTED_AT = @"lastCollectedAt";

- (void)archive {
    dispatch_sync(_serial, ^{
        NSDictionary *archive = @{SF_BUCKET: _bucket, SF_LAST_COLLECTED_AT: @(_lastCollectedAt)};
        [NSKeyedArchiver archiveRootObject:archive toFile:_archivePath];
    });
}

- (void)unarchive {
    dispatch_sync(_serial, ^{
        NSDictionary *archive = [NSKeyedUnarchiver unarchiveObjectWithFile:_archivePath];
        if (archive) {
            _bucket = archive[SF_BUCKET];
            _lastCollectedAt = ((NSNumber *)archive[SF_LAST_COLLECTED_AT]).unsignedLongLongValue;
        } else {
            _bucket = [[SFTokenBucket alloc] initWithNumTokens:SF_COLLECTION_RATE_LIMIT_NUM_COLLECTIONS interval:SF_COLLECTION_RATE_LIMIT_PERIOD];
            _lastCollectedAt = 0;
        }
    });
}

@end
