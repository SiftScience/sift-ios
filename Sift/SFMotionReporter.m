// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreMotion;
@import Foundation;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFMotionReporter.h"
#import "SFUtils.h"
#import "Sift.h"

static NSString *MOTION_EVENT_TYPE = @"$motion";

static const SFMotionReporterConfig DEFAULT_CONFIG = {
    .readAccelerometer = YES,
    .accelerometerUpdateInterval = 1,

    .readGyroscope = YES,
    .gyroUpdateInterval = 1,

    .readMagnetometer = YES,
    .magnetometerUpdateInterval = 1,

    .readDeviceMotion = YES,
    .deviceMotionUpdateInterval = 1,
};

@implementation SFMotionReporter {
    SFMotionReporterConfig _config;
    CMMotionManager *_manager;
    NSOperationQueue *_queue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _config = DEFAULT_CONFIG;
        _manager = [CMMotionManager new];
        _queue = [NSOperationQueue new];
    }
    return self;
}

- (void)start:(SFMotionReporterConfig)config {
    _config = config;
    [self start];
}

// TODO(clchiou): Measure how much data motion reporter generates (probably too much data?).

- (void)start {
    if (_config.readAccelerometer && _manager.accelerometerAvailable && !_manager.accelerometerActive) {
        SF_DEBUG(@"Start accelerometer");
        _manager.accelerometerUpdateInterval = _config.accelerometerUpdateInterval;
        [_manager startAccelerometerUpdatesToQueue:_queue withHandler:^(CMAccelerometerData *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Accelerometer error: %@", [error localizedDescription]);
                [_manager stopAccelerometerUpdates];
                return;
            }
            Sift *sift = [Sift sharedInstance];
            NSDictionary *fields = @{@"raw_acceleration_x": SFDoubleToString(data.acceleration.x),
                                     @"raw_acceleration_y": SFDoubleToString(data.acceleration.y),
                                     @"raw_acceleration_z": SFDoubleToString(data.acceleration.z)};
            SFEvent *event = [SFEvent eventWithPath:nil mobileEventType:MOTION_EVENT_TYPE userId:sift.userId fields:fields];
            event.time = data.timestamp * 1000.0;
            [sift appendEvent:event];
        }];
    }

    if (_config.readGyroscope && _manager.gyroAvailable && !_manager.gyroActive) {
        SF_DEBUG(@"Start gyroscope");
        _manager.gyroUpdateInterval = _config.gyroUpdateInterval;
        [_manager startGyroUpdatesToQueue:_queue withHandler:^(CMGyroData *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Gyroscope error: %@", [error localizedDescription]);
                [_manager stopGyroUpdates];
                return;
            }
            Sift *sift = [Sift sharedInstance];
            NSDictionary *fields = @{@"raw_rotation_rate_x": SFDoubleToString(data.rotationRate.x),
                                     @"raw_rotation_rate_y": SFDoubleToString(data.rotationRate.y),
                                     @"raw_rotation_rate_z": SFDoubleToString(data.rotationRate.z)};
            SFEvent *event = [SFEvent eventWithPath:nil mobileEventType:MOTION_EVENT_TYPE userId:sift.userId fields:fields];
            event.time = data.timestamp * 1000.0;
            [sift appendEvent:event];
        }];
    }

    if (_config.readMagnetometer && _manager.magnetometerAvailable && !_manager.magnetometerActive) {
        SF_DEBUG(@"Start magnetometer");
        _manager.magnetometerUpdateInterval = _config.magnetometerUpdateInterval;
        [_manager startMagnetometerUpdatesToQueue:_queue withHandler:^(CMMagnetometerData *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Magnetometer error: %@", [error localizedDescription]);
                [_manager stopMagnetometerUpdates];
                return;
            }
            Sift *sift = [Sift sharedInstance];
            NSDictionary *fields = @{@"raw_magnetic_field_x": SFDoubleToString(data.magneticField.x),
                                     @"raw_magnetic_field_y": SFDoubleToString(data.magneticField.y),
                                     @"raw_magnetic_field_z": SFDoubleToString(data.magneticField.z)};
            SFEvent *event = [SFEvent eventWithPath:nil mobileEventType:MOTION_EVENT_TYPE userId:sift.userId fields:fields];
            event.time = data.timestamp * 1000.0;
            [sift appendEvent:event];
        }];
    }

    if (_config.readDeviceMotion && _manager.deviceMotionAvailable && !_manager.deviceMotionActive) {
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
        SF_DEBUG(@"Start device motion service: frame=%lu", (unsigned long)frame);
        _manager.deviceMotionUpdateInterval = _config.deviceMotionUpdateInterval;
        [_manager startDeviceMotionUpdatesUsingReferenceFrame:frame toQueue:_queue withHandler:^(CMDeviceMotion *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Device motion error: %@", [error localizedDescription]);
                [_manager stopDeviceMotionUpdates];
                return;
            }
            Sift *sift = [Sift sharedInstance];
            NSMutableDictionary *fields = [NSMutableDictionary new];
            fields[@"attitude_roll"] = SFDoubleToString(data.attitude.roll);
            fields[@"attitude_pitch"] = SFDoubleToString(data.attitude.pitch);
            fields[@"attitude_yaw"] = SFDoubleToString(data.attitude.yaw);
            fields[@"rotation_rate_x"] = SFDoubleToString(data.rotationRate.x);
            fields[@"rotation_rate_y"] = SFDoubleToString(data.rotationRate.y);
            fields[@"rotation_rate_z"] = SFDoubleToString(data.rotationRate.z);
            fields[@"gravity_x"] = SFDoubleToString(data.gravity.x);
            fields[@"gravity_y"] = SFDoubleToString(data.gravity.y);
            fields[@"gravity_z"] = SFDoubleToString(data.gravity.z);
            fields[@"user_acceleration_x"] = SFDoubleToString(data.userAcceleration.x);
            fields[@"user_acceleration_y"] = SFDoubleToString(data.userAcceleration.y);
            fields[@"user_acceleration_z"] = SFDoubleToString(data.userAcceleration.z);
            if (data.magneticField.accuracy != CMMagneticFieldCalibrationAccuracyUncalibrated) {
                fields[@"magnetic_field_x"] = SFDoubleToString(data.magneticField.field.x);
                fields[@"magnetic_field_y"] = SFDoubleToString(data.magneticField.field.y);
                fields[@"magnetic_field_z"] = SFDoubleToString(data.magneticField.field.z);
                fields[@"magnetic_field_accuracy"] = [NSNumber numberWithInteger:data.magneticField.accuracy].stringValue;
            }
            SFEvent *event = [SFEvent eventWithPath:nil mobileEventType:MOTION_EVENT_TYPE userId:sift.userId fields:fields];
            event.time = data.timestamp * 1000.0;
            [sift appendEvent:event];
        }];
    }
}

- (void)stop {
    SF_DEBUG(@"Stop motion reporter");
    [_manager stopAccelerometerUpdates];
    [_manager stopGyroUpdates];
    [_manager stopMagnetometerUpdates];
    [_manager stopDeviceMotionUpdates];
}

@end