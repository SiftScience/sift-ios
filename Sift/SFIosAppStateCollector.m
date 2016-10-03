// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import CoreMotion;
@import Foundation;
@import UIKit;

#import "SFCircularBuffer.h"
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

// Motion sensor parameters.
static const NSUInteger     SF_MOTION_SENSOR_NUM_READINGS = 10;  // Keep at most 10 readings.
static const NSTimeInterval SF_MOTION_SENSOR_INTERVAL = 0.5;  // Unit: second.

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

    //// Motion sensors.

    BOOL _allowUsingMotionSensors;
    CMMotionManager *_motionManager;
    int _numMotionStarted;
    NSOperationQueue *_operationQueue;
    SFCircularBuffer<CMDeviceMotion *> *_deviceMotionReadings;
    SFCircularBuffer<CMAccelerometerData *> *_accelerometerReadings;
    SFCircularBuffer<CMGyroData *> *_gyroReadings;
    SFCircularBuffer<CMMagnetometerData *> *_magnetometerReadings;

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

        //// Motion sensors.

        _allowUsingMotionSensors = NO;

        // Create a CMMotionManager object but don't start/stop motion sensors unless we are allowed to do so.
        _motionManager = [CMMotionManager new];
        _numMotionStarted = 0;

        _operationQueue = [NSOperationQueue new];
        _deviceMotionReadings = [[SFCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
        _accelerometerReadings = [[SFCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
        _gyroReadings = [[SFCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
        _magnetometerReadings = [[SFCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
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
    // Suspend serial queue and stop motion sensors (if we have started
    // them) after requestCollection's block is executed.  And we will
    // not re-start motion sensors when we are back to the foreground,
    // by the way.
    dispatch_async(_serial, ^{
        [self stopMotionSensors];
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

    BOOL foreground = UIApplication.sharedApplication.applicationState == UIApplicationStateActive;

    // Don't start motion sensors when you are in the background.
    if (_allowUsingMotionSensors && foreground) {
        SF_DEBUG(@"Collect motion data...");
        [self startMotionSensors];

        // Wait for a full cycle of readings plus 0.1 second margin to collect motion sensor readings.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (SF_MOTION_SENSOR_INTERVAL * SF_MOTION_SENSOR_NUM_READINGS + 0.1) * NSEC_PER_SEC), _serial, ^{
            [self stopMotionSensors];
            [self addReadingsToIosAppState:event.iosAppState];
            [Sift.sharedInstance appendEvent:event];
        });
    } else {
        [self addReadingsToIosAppState:event.iosAppState];
        [Sift.sharedInstance appendEvent:event];
    }

    _lastCollectedAt = now;

    // Don't schedule a check in the future if you are in the background.
    if (foreground) {
        // We don't care whether the remaining requests are executed if we are gone.
        SFIosAppStateCollector * __weak weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, SF_MAX_COLLECTION_PERIOD * NSEC_PER_MSEC), _serial, ^{
            [weakSelf checkAndCollectWhenNoneRecently:SFCurrentTime()];
        });
    }
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

#pragma mark - Motion sensors

- (BOOL)allowUsingMotionSensors {
    return _allowUsingMotionSensors;
}

- (void)setAllowUsingMotionSensors:(BOOL)allowUsingMotionSensors {
    if (_allowUsingMotionSensors && !allowUsingMotionSensors) {
        SF_DEBUG(@"We are not allowed to use motion sensors anymore");
        [self stopMotionSensors];
    }
    _allowUsingMotionSensors = allowUsingMotionSensors;
}

- (void)updateDeviceMotion:(CMDeviceMotion *)data {
    @synchronized (_deviceMotionReadings) {
        [_deviceMotionReadings append:data];
    }
}

- (void)updateAccelerometerData:(CMAccelerometerData *)data {
    @synchronized (_accelerometerReadings) {
        [_accelerometerReadings append:data];
    }
}

- (void)updateGyroData:(CMGyroData *)data {
    @synchronized (_gyroReadings) {
        [_gyroReadings append:data];
    }
}

- (void)updateMagnetometerData:(CMMagnetometerData *)data {
    @synchronized (_magnetometerReadings) {
        [_magnetometerReadings append:data];
    }
}

- (void)startMotionSensors {
    if (_numMotionStarted++ > 0) {
        return;
    }

    // Prefer device motion over raw sensor data
    if (_motionManager.isDeviceMotionAvailable) {
        CMAttitudeReferenceFrame frame;
        CMAttitudeReferenceFrame available = [CMMotionManager availableAttitudeReferenceFrames];
        if (available & CMAttitudeReferenceFrameXTrueNorthZVertical) {
            frame = CMAttitudeReferenceFrameXTrueNorthZVertical;
        } else if (available & CMAttitudeReferenceFrameXMagneticNorthZVertical) {
            frame = CMAttitudeReferenceFrameXMagneticNorthZVertical;
        } else if (available & CMAttitudeReferenceFrameXArbitraryCorrectedZVertical) {
            frame = CMAttitudeReferenceFrameXArbitraryCorrectedZVertical;
        } else {
            frame = CMAttitudeReferenceFrameXArbitraryZVertical;
        }
        SF_DEBUG(@"Start device motion sensor: frame=%lu", (unsigned long)frame);
        _motionManager.deviceMotionUpdateInterval = SF_MOTION_SENSOR_INTERVAL;
        [_motionManager startDeviceMotionUpdatesUsingReferenceFrame:frame toQueue:_operationQueue withHandler:^(CMDeviceMotion *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Device motion error: %@", [error localizedDescription]);
                return;
            }
            [self updateDeviceMotion:data];
        }];
    } else {
        SF_DEBUG(@"Start raw motion sensors");
        if (_motionManager.accelerometerAvailable) {
            _motionManager.accelerometerUpdateInterval = SF_MOTION_SENSOR_INTERVAL;
            [_motionManager startAccelerometerUpdatesToQueue:_operationQueue withHandler:^(CMAccelerometerData *data, NSError *error) {
                if (error) {
                    SF_DEBUG(@"Accelerometer error: %@", [error localizedDescription]);
                    return;
                }
                [self updateAccelerometerData:data];
            }];
        }
        if (_motionManager.gyroAvailable) {
            _motionManager.gyroUpdateInterval = SF_MOTION_SENSOR_INTERVAL;
            [_motionManager startGyroUpdatesToQueue:_operationQueue withHandler:^(CMGyroData *data, NSError *error) {
                if (error) {
                    SF_DEBUG(@"Gyro error: %@", [error localizedDescription]);
                    return;
                }
                [self updateGyroData:data];
            }];
        }
        if (_motionManager.magnetometerAvailable) {
            _motionManager.magnetometerUpdateInterval = SF_MOTION_SENSOR_INTERVAL;
            [_motionManager startMagnetometerUpdatesToQueue:_operationQueue withHandler:^(CMMagnetometerData *data, NSError *error) {
                if (error) {
                    SF_DEBUG(@"Magnetometer error: %@", [error localizedDescription]);
                    return;
                }
                [self updateMagnetometerData:data];
            }];
        }
    }
}

- (void)stopMotionSensors {
    if (--_numMotionStarted > 0) {
        return;
    }
    // Excessive calls to `stopMotionSensors` are no-ops.
    if (_numMotionStarted < 0) {
        _numMotionStarted = 0;
        return;
    }

    // Prefer device motion over raw sensor data
    if (_motionManager.isDeviceMotionAvailable) {
        SF_DEBUG(@"Stop device motion sensors");
        [_motionManager stopDeviceMotionUpdates];
    } else {
        SF_DEBUG(@"Stop raw motion sensors");
        [_motionManager stopAccelerometerUpdates];
        [_motionManager stopGyroUpdates];
        [_motionManager stopMagnetometerUpdates];
    }
}

- (void)addReadingsToIosAppState:(SFHtDictionary *)iosAppState {
    NSArray<NSDictionary *> *motion = [self convertReadings:_deviceMotionReadings converter:SFCMDeviceMotionToDictionary];
    if (motion.count) {
        [iosAppState setEntry:@"motion" value:motion];
    }
    NSArray<NSDictionary *> *rawAccelerometer = [self convertReadings:_accelerometerReadings converter:SFCMAccelerometerDataToDictionary];
    if (rawAccelerometer.count) {
        [iosAppState setEntry:@"raw_accelerometer" value:rawAccelerometer];
    }
    NSArray<NSDictionary *> *rawGyro = [self convertReadings:_gyroReadings converter:SFCMGyroDataToDictionary];
    if (rawGyro.count) {
        [iosAppState setEntry:@"raw_gyro" value:rawGyro];
    }
    NSArray<NSDictionary *> *rawMagnetometer = [self convertReadings:_magnetometerReadings converter:SFCMMagnetometerDataToDictionary];
    if (rawMagnetometer.count) {
        [iosAppState setEntry:@"raw_magnetometer" value:rawMagnetometer];
    }
}

- (NSArray<NSDictionary *> *)convertReadings:(SFCircularBuffer *)buffer converter:(void *)converter {
    NSMutableArray<NSDictionary *> *readings = [NSMutableArray new];
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
