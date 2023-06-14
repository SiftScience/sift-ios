// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import CoreMotion;
@import Foundation;
@import UIKit;

#import "SiftCircularBuffer.h"
#import "SiftCompatibility.h"
#import "SiftDebug.h"
#import "SiftEvent.h"
#import "SiftEvent+Private.h"
#import "SiftIosAppState.h"
#import "SiftTokenBucket.h"
#import "SiftUtils.h"
#import "Sift.h"
#import "TaskManager.h"

#import "SiftIosAppStateCollector.h"
#import "SiftIosAppStateCollector+Private.h"

// We rate limit to no more than 30 collections in 1 minute.
static const double         SF_COLLECTION_RATE_LIMIT_NUM_COLLECTIONS = 30;
static const NSTimeInterval SF_COLLECTION_RATE_LIMIT_PERIOD = 60; // Unit: second.

// If there was no collection in the last 2 minutes, request a collection.
static const SFTimestamp SF_MAX_COLLECTION_PERIOD = 120000;  // Unit: millisecond.

// Compass (heading) parameter.
// We will wait for 4 seconds for the first heading update.  (On an
// iPhone 4S it takes 2 ~ 3 seconds to get the first heading update.
// And we add 1 second as a margin; so that's 4 seconds.)
static const unsigned long long SF_HEADING_INTERVAL = 4 * NSEC_PER_SEC;

@implementation SiftIosAppStateCollector {
    TaskManager *_taskManager;
    // Use serial queue as an alternative to locking.
    dispatch_queue_t _serial;
    dispatch_source_t _source;
    NSString *_archivePath;
    CLLocationManager *_locationManager;

    BOOL _disallowCollectingLocationData;
    NSOperationQueue *_operationQueue;

    //// Archived states.
    SiftTokenBucket *_bucket;  // Control the rate of requestCollection.
    SFTimestamp _lastCollectedAt;  // Control the rate of checkAndCollectWhenNoneRecently.
}

- (instancetype)initWithArchivePath:(NSString *)archivePath {
    self = [super init];
    if (self) {
        _taskManager = [[TaskManager alloc] init];
        _serial = dispatch_queue_create("com.sift.SFIosAppStateCollector", DISPATCH_QUEUE_SERIAL);
        _archivePath = archivePath;
        _locationManager = [CLLocationManager new];
        _serialSuspendCounter = 0;

        [self unarchive];

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(willEnterForeground) name:UIApplicationWillEnterForegroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(didBecomeActive) name:UIApplicationDidBecomeActiveNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(didEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(viewControllerDidChange:) name:
            @"UINavigationControllerDidShowViewControllerNotification" object:nil];

        // Also check periodically.
        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _serial);
        dispatch_source_set_timer(_source, dispatch_time(DISPATCH_TIME_NOW, 0), SF_MAX_COLLECTION_PERIOD * NSEC_PER_MSEC, 10 * NSEC_PER_SEC);
        SiftIosAppStateCollector * __weak weakSelf = self;
        dispatch_source_set_event_handler(_source, ^{
            [weakSelf checkAndCollectWhenNoneRecently:SFCurrentTime()];
        });
        dispatch_resume(_source);
        
        _disallowCollectingLocationData = NO;

        _operationQueue = [NSOperationQueue new];
    }
    return self;
}

- (void)willEnterForeground {
    if (_serialSuspendCounter <= 0) {
        SF_DEBUG(@"Suspend counter has reached zero – do not resume");
        return;
    }
    
    dispatch_resume(_serial);
    _serialSuspendCounter--;
}

- (void)didBecomeActive {
    [self requestCollectionWithTitle:nil];
}

- (void)didEnterBackground {
    // Suspend serial queue and stop motion sensors (if we have started them).
    // We will not re-start motion sensors when we are back to the foreground.
    [_taskManager submitWithTask:^{
        [self->_locationManager stopUpdatingHeading];
        dispatch_suspend(self->_serial);
        self->_serialSuspendCounter++;
    } queue:_serial];
}

- (void)viewControllerDidChange:(NSNotification *)notification {
    UIViewController *dest = [[notification userInfo]
                               objectForKey:@"UINavigationControllerNextVisibleViewController"];
    [self requestCollectionWithTitle:NSStringFromClass([dest class])];
    
}

- (void)requestCollectionWithTitle:(NSString *)title {
    // We don't care whether the remaining requests are executed if we are gone.
    SiftIosAppStateCollector * __weak weakSelf = self;
    [_taskManager submitWithTask:^{
        SiftIosAppStateCollector *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (![self->_bucket tryAcquire]) {
            SF_DEBUG(@"Ignore collection request due to rate limit");
            return;
        }

        [strongSelf collectWithTitle:title andTimestamp:SFCurrentTime()];
    } queue:_serial];
}

- (void)checkAndCollectWhenNoneRecently:(SFTimestamp)now {
    [_taskManager submitWithTask:^{
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            SF_DEBUG(@"Ignore collection request since the app is in the background");
            return;
        }
        [self->_taskManager submitWithTask:^{
            if (self->_lastCollectedAt > 0) {
                if (self->_lastCollectedAt + SF_MAX_COLLECTION_PERIOD >= now) {
                    SF_DEBUG(@"Ignore collection request since it is not long enough since last collection");
                    return;
                }
            }
            [self collectWithTitle:nil andTimestamp:now];
        } queue:self->_serial];
    } queue:dispatch_get_main_queue()];
}

- (void)collectWithTitle:(NSString *)title andTimestamp:(SFTimestamp)now {
    [_taskManager submitWithTask:^{
        SF_DEBUG(@"Collect app state...");
        SiftEvent *event = [SiftEvent new];
        event.time = now;
        event.iosAppState = SFCollectIosAppState(self->_locationManager, title);

        BOOL foreground = UIApplication.sharedApplication.applicationState != UIApplicationStateBackground;
        
        [self->_taskManager submitWithTask:^{
            // Don't start compass and motion sensors when you are in the background.
            int64_t delay = 0;
            if (foreground) {
                [self->_locationManager startUpdatingHeading];
                delay = MAX(delay, SF_HEADING_INTERVAL);
            }
            
            if (delay > 0) {
                [self->_taskManager scheduleWithTask:^{
                    if ([self canCollectLocationData] && self->_locationManager.location) {
                        [event.iosAppState setObject:SFCLLocationToDictionary(self->_locationManager.location) forKey:@"location"];
                    }
                    
                    [self->_locationManager stopUpdatingHeading];
                    
                    SF_DEBUG(@"iosAppState: %@", event.iosAppState);
                    [Sift.sharedInstance appendEvent:event];
                } queue:self->_serial delay:delay];
            } else {
                if ([self canCollectLocationData] && self->_locationManager.location) {
                    [event.iosAppState setObject:SFCLLocationToDictionary(self->_locationManager.location) forKey:@"location"];
                }
                
                SF_DEBUG(@"iosAppState: %@", event.iosAppState);
                [Sift.sharedInstance appendEvent:event];
            }
            
            self->_lastCollectedAt = now;
            
            // Don't schedule a check in the future if you are in the background.
            if (foreground) {
                // We don't care whether the remaining requests are executed if we are gone.
                SiftIosAppStateCollector * __weak weakSelf = self;
                [self->_taskManager scheduleWithTask:^{
                    [weakSelf checkAndCollectWhenNoneRecently:SFCurrentTime()];
                } queue:self->_serial delay:SF_MAX_COLLECTION_PERIOD * NSEC_PER_MSEC];
            }
        } queue:self->_serial];
    } queue:dispatch_get_main_queue()];
}

#pragma mark - NSKeyedArchiver/NSKeyedUnarchiver

static NSString * const SF_BUCKET = @"bucket";
static NSString * const SF_LAST_COLLECTED_AT = @"lastCollectedAt";

- (void)archive {
    dispatch_sync(_serial, ^{
        NSDictionary *archive = @{SF_BUCKET: _bucket, SF_LAST_COLLECTED_AT: @(_lastCollectedAt)};
        
        NSData* data = [NSKeyedArchiver archivedDataWithRootObject: archive requiringSecureCoding:NO error:nil];
        [data writeToFile:self->_archivePath options:NSDataWritingAtomic error:nil];
        
    });
}

- (void)unarchive {
    dispatch_sync(_serial, ^{
        NSDictionary *archive;
        NSData *newData = [NSData dataWithContentsOfFile:_archivePath];
        NSError *error;
        
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:newData error:&error];
        unarchiver.requiresSecureCoding = NO;
        archive = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
        SF_DEBUG(@"error unarchiving data: %@", error.localizedDescription);

        if (archive) {
            _bucket = archive[SF_BUCKET];
            _lastCollectedAt = ((NSNumber *)archive[SF_LAST_COLLECTED_AT]).unsignedLongLongValue;
        } else {
            _bucket = [[SiftTokenBucket alloc] initWithNumTokens:SF_COLLECTION_RATE_LIMIT_NUM_COLLECTIONS interval:SF_COLLECTION_RATE_LIMIT_PERIOD];
            _lastCollectedAt = 0;
        }
    });
}

#pragma mark – Location collection

- (BOOL)disallowCollectingLocationData {
    return _disallowCollectingLocationData;
}

- (void)setDisallowCollectingLocationData:(BOOL)disallowCollectingLocationData {
    _disallowCollectingLocationData = disallowCollectingLocationData;
}

- (BOOL)canCollectLocationData {
    return (CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways ||
             CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse) &&
            !_disallowCollectingLocationData;
}

- (SF_GENERICS(NSArray, NSDictionary *) *)convertReadings:(SiftCircularBuffer *)buffer converter:(void *)converter {
    SF_GENERICS(NSMutableArray, NSDictionary *) *readings = [NSMutableArray new];
    NSDate *uptime = [NSDate dateWithTimeIntervalSinceNow:-NSProcessInfo.processInfo.systemUptime];
    @synchronized (buffer) {
        for (CMLogItem *reading in [buffer shallowCopy]) {
            // CMLogItem records timestamp since device boot.
            SFTimestamp timestamp = [[uptime dateByAddingTimeInterval:reading.timestamp] timeIntervalSince1970] * 1000;
            [readings addObject:((NSDictionary *(*)(CMLogItem *, SFTimestamp))converter)(reading, timestamp)];
        }
        [buffer removeAllObjects];
    }
    return readings;
}

@end
