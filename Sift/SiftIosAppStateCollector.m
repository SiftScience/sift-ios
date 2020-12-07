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

// Motion sensor parameters.
static const NSUInteger     SF_MOTION_SENSOR_NUM_READINGS = 10;  // Keep at most 10 readings.
static const NSTimeInterval SF_MOTION_SENSOR_INTERVAL = 0.5;  // Unit: second.

@implementation SiftIosAppStateCollector {
    // Use serial queue as an alternative to locking.
    dispatch_queue_t _serial;
    dispatch_source_t _source;
    NSString *_archivePath;
    CLLocationManager *_locationManager;

    //// Motion sensors.
    BOOL _allowUsingMotionSensors;
    BOOL _disallowCollectingLocationData;
    CMMotionManager *_motionManager;
    int _numMotionStarted;
    NSOperationQueue *_operationQueue;
    SF_GENERICS(SiftCircularBuffer, CMDeviceMotion *) *_deviceMotionReadings;
    SF_GENERICS(SiftCircularBuffer, CMAccelerometerData *) *_accelerometerReadings;
    SF_GENERICS(SiftCircularBuffer, CMGyroData *) *_gyroReadings;
    SF_GENERICS(SiftCircularBuffer, CMMagnetometerData *) *_magnetometerReadings;

    //// Archived states.
    SiftTokenBucket *_bucket;  // Control the rate of requestCollection.
    SFTimestamp _lastCollectedAt;  // Control the rate of checkAndCollectWhenNoneRecently.
}

- (instancetype)initWithArchivePath:(NSString *)archivePath {
    self = [super init];
    if (self) {
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

        //// Motion sensors.

        _allowUsingMotionSensors = NO;

        // Create a CMMotionManager object but don't start/stop motion sensors unless we are allowed to do so.
        _motionManager = [CMMotionManager new];
        _numMotionStarted = 0;

        _operationQueue = [NSOperationQueue new];
        _deviceMotionReadings = [[SiftCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
        _accelerometerReadings = [[SiftCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
        _gyroReadings = [[SiftCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
        _magnetometerReadings = [[SiftCircularBuffer alloc] initWithSize:SF_MOTION_SENSOR_NUM_READINGS];
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
    dispatch_async(_serial, ^{
        [self stopMotionSensors];
        [self->_locationManager stopUpdatingHeading];
        dispatch_suspend(self->_serial);
        self->_serialSuspendCounter++;
    });
}

- (void)viewControllerDidChange:(NSNotification *)notification {
    UIViewController *dest = [[notification userInfo]
                               objectForKey:@"UINavigationControllerNextVisibleViewController"];
    [self requestCollectionWithTitle:NSStringFromClass([dest class])];
    
}

- (void)requestCollectionWithTitle:(NSString *)title {
    // We don't care whether the remaining requests are executed if we are gone.
    SiftIosAppStateCollector * __weak weakSelf = self;
    dispatch_async(_serial, ^{
        SiftIosAppStateCollector *strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }

        if (![self->_bucket tryAcquire]) {
            SF_DEBUG(@"Ignore collection request due to rate limit");
            return;
        }

        [strongSelf collectWithTitle:title andTimestamp:SFCurrentTime()];
    });
}

- (void)checkAndCollectWhenNoneRecently:(SFTimestamp)now {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
            SF_DEBUG(@"Ignore collection request since the app is in the background");
            return;
        }
        
        dispatch_async(self->_serial, ^{
            if (self->_lastCollectedAt > 0) {
                if (self->_lastCollectedAt + SF_MAX_COLLECTION_PERIOD >= now) {
                    SF_DEBUG(@"Ignore collection request since it is not long enough since last collection");
                    return;
                }
            }
            
            [self collectWithTitle:nil andTimestamp:now];
        });
    });
}

- (void)collectWithTitle:(NSString *)title andTimestamp:(SFTimestamp)now {
    dispatch_async(dispatch_get_main_queue(), ^{
        SF_DEBUG(@"Collect app state...");
        SiftEvent *event = [SiftEvent new];
        event.time = now;
        event.iosAppState = SFCollectIosAppState(self->_locationManager, title);

        BOOL foreground = UIApplication.sharedApplication.applicationState != UIApplicationStateBackground;
        
        dispatch_async(self->_serial, ^{
            // Don't start compass and motion sensors when you are in the background.
            int64_t delay = 0;
            if (foreground) {
                if (self->_allowUsingMotionSensors) {
                    SF_DEBUG(@"Collect motion data...");
                    [self startMotionSensors];
                    // Wait for a full cycle of readings plus 0.1 second margin to collect motion sensor readings.
                    delay = MAX(delay, (SF_MOTION_SENSOR_INTERVAL * SF_MOTION_SENSOR_NUM_READINGS + 0.1) * NSEC_PER_SEC);
                }
                
                [self->_locationManager startUpdatingHeading];
                delay = MAX(delay, SF_HEADING_INTERVAL);
            }
            
            if (delay > 0) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), self->_serial, ^{
                    [self stopMotionSensors];
                    
                    if ([self canCollectLocationData] && self->_locationManager.location) {
                        [event.iosAppState setEntry:@"location" value:SFCLLocationToDictionary(self->_locationManager.location).entries];
                    }
                    
                    // Read heading before we stop location manager (it nullifies heading when stopped).
                    CLHeading *heading = self->_locationManager.heading;
                    [self->_locationManager stopUpdatingHeading];
                    
                    if (heading) {
                        [event.iosAppState setEntry:@"heading" value:SFCLHeadingToDictionary(heading).entries];
                    }
                    
                    [self addReadingsToIosAppState:event.iosAppState];
                    
                    SF_DEBUG(@"iosAppState: %@", event.iosAppState.entries);
                    [Sift.sharedInstance appendEvent:event];
                });
            } else {
                if ([self canCollectLocationData] && self->_locationManager.location) {
                    [event.iosAppState setEntry:@"location" value:SFCLLocationToDictionary(self->_locationManager.location).entries];
                }
                
                CLHeading *heading = self->_locationManager.heading;
                if (heading) {
                    [event.iosAppState setEntry:@"heading" value:SFCLHeadingToDictionary(heading).entries];
                }
                
                [self addReadingsToIosAppState:event.iosAppState];
                
                SF_DEBUG(@"iosAppState: %@", event.iosAppState.entries);
                [Sift.sharedInstance appendEvent:event];
            }
            
            self->_lastCollectedAt = now;
            
            // Don't schedule a check in the future if you are in the background.
            if (foreground) {
                // We don't care whether the remaining requests are executed if we are gone.
                SiftIosAppStateCollector * __weak weakSelf = self;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, SF_MAX_COLLECTION_PERIOD * NSEC_PER_MSEC), self->_serial, ^{
                    [weakSelf checkAndCollectWhenNoneRecently:SFCurrentTime()];
                });
            }
        });
    });
}

#pragma mark - NSKeyedArchiver/NSKeyedUnarchiver

static NSString * const SF_BUCKET = @"bucket";
static NSString * const SF_LAST_COLLECTED_AT = @"lastCollectedAt";

- (void)archive {
    dispatch_sync(_serial, ^{
        NSDictionary *archive = @{SF_BUCKET: _bucket, SF_LAST_COLLECTED_AT: @(_lastCollectedAt)};
        #if TARGET_OS_MACCATALYST
            NSData* data = [NSKeyedArchiver archivedDataWithRootObject: archive requiringSecureCoding:NO error:nil];
            [data writeToFile:self->_archivePath options:NSDataWritingAtomic error:nil];
        #else
            if (@available(iOS 11.0, *)) {
                NSData* data = [NSKeyedArchiver archivedDataWithRootObject: archive requiringSecureCoding:NO error:nil];
                [data writeToFile:self->_archivePath options:NSDataWritingAtomic error:nil];
            } else {
                [NSKeyedArchiver archiveRootObject:archive toFile:self->_archivePath];
            }
        #endif
    });
}

- (void)unarchive {
    dispatch_sync(_serial, ^{
        NSDictionary *archive;
        NSData *newData = [NSData dataWithContentsOfFile:_archivePath];
        NSError *error;
        #if TARGET_OS_MACCATALYST
            NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:newData error:&error];
            unarchiver.requiresSecureCoding = NO;
            archive = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
            SF_DEBUG(@"error unarchiving data: %@", error.localizedDescription);
        #else
            if (@available(iOS 11.0, *)) {
                NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:newData error:&error];
                unarchiver.requiresSecureCoding = NO;
                archive = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:&error];
                SF_DEBUG(@"error unarchiving data: %@", error.localizedDescription);
            } else {
                archive = [NSKeyedUnarchiver unarchiveObjectWithFile:_archivePath];
            }
        #endif
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
        // Need casting here to fix a compiler warning because in Base SDK 8 (shipped with Xcode 6), CMAttitudeReferenceFrame is not defined using NS_ENUM.
        CMAttitudeReferenceFrame available = (CMAttitudeReferenceFrame)[CMMotionManager availableAttitudeReferenceFrames];
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

- (void)addReadingsToIosAppState:(SiftHtDictionary *)iosAppState {
    SF_GENERICS(NSArray, NSDictionary *) *motion = [self convertReadings:_deviceMotionReadings converter:SFCMDeviceMotionToDictionary];
    if (motion.count) {
        [iosAppState setEntry:@"motion" value:motion];
    }
    SF_GENERICS(NSArray, NSDictionary *) *rawAccelerometer = [self convertReadings:_accelerometerReadings converter:SFCMAccelerometerDataToDictionary];
    if (rawAccelerometer.count) {
        [iosAppState setEntry:@"raw_accelerometer" value:rawAccelerometer];
    }
    SF_GENERICS(NSArray, NSDictionary *) *rawGyro = [self convertReadings:_gyroReadings converter:SFCMGyroDataToDictionary];
    if (rawGyro.count) {
        [iosAppState setEntry:@"raw_gyro" value:rawGyro];
    }
    SF_GENERICS(NSArray, NSDictionary *) *rawMagnetometer = [self convertReadings:_magnetometerReadings converter:SFCMMagnetometerDataToDictionary];
    if (rawMagnetometer.count) {
        [iosAppState setEntry:@"raw_magnetometer" value:rawMagnetometer];
    }
}

- (SF_GENERICS(NSArray, NSDictionary *) *)convertReadings:(SiftCircularBuffer *)buffer converter:(void *)converter {
    SF_GENERICS(NSMutableArray, NSDictionary *) *readings = [NSMutableArray new];
    NSDate *uptime = [NSDate dateWithTimeIntervalSinceNow:-NSProcessInfo.processInfo.systemUptime];
    @synchronized (buffer) {
        for (CMLogItem *reading in [buffer shallowCopy]) {
            // CMLogItem records timestamp since device boot.
            SFTimestamp timestamp = [[uptime dateByAddingTimeInterval:reading.timestamp] timeIntervalSince1970] * 1000;
            [readings addObject:((SiftHtDictionary *(*)(CMLogItem *, SFTimestamp))converter)(reading, timestamp).entries];
        }
        [buffer removeAllObjects];
    }
    return readings;
}

@end
