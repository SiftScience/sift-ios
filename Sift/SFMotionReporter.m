// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreMotion;
@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFMotionReporter.h"

static NSString * const SFMotionEventType = @"$motion";

@implementation SFMotionReporter {
    CMMotionManager *_manager;
    NSOperationQueue *_queue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _manager = [CMMotionManager new];
        _queue = [NSOperationQueue new];
    }
    return self;
}

- (void)collect:(NSTimeInterval)delay period:(NSTimeInterval)period numSamples:(int)numSamples {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [self start:numSamples];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (delay + period) * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [self stop];
    });
}

- (void)start:(int)numSamples {
    NSTimeInterval interval = 1.0 / numSamples;

    if (_manager.accelerometerAvailable && !_manager.accelerometerActive) {
        SF_DEBUG(@"Start accelerometer");
        _manager.accelerometerUpdateInterval = interval;
        [_manager startAccelerometerUpdatesToQueue:_queue withHandler:^(CMAccelerometerData *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Accelerometer error: %@", [error localizedDescription]);
                [_manager stopAccelerometerUpdates];
                return;
            }
            NSDictionary *fields = @{@"raw_acceleration_x": SFDoubleToString(data.acceleration.x),
                                     @"raw_acceleration_y": SFDoubleToString(data.acceleration.y),
                                     @"raw_acceleration_z": SFDoubleToString(data.acceleration.z)};
            SFEvent *event = [SFEvent eventWithType:SFMotionEventType path:nil fields:fields];
            event.time = data.timestamp * 1000.0;
            [[Sift sharedInstance] appendEvent:event];
        }];
    }

    if (_manager.gyroAvailable && !_manager.gyroActive) {
        SF_DEBUG(@"Start gyroscope");
        _manager.gyroUpdateInterval = interval;
        [_manager startGyroUpdatesToQueue:_queue withHandler:^(CMGyroData *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Gyroscope error: %@", [error localizedDescription]);
                [_manager stopGyroUpdates];
                return;
            }
            NSDictionary *fields = @{@"raw_rotation_rate_x": SFDoubleToString(data.rotationRate.x),
                                     @"raw_rotation_rate_y": SFDoubleToString(data.rotationRate.y),
                                     @"raw_rotation_rate_z": SFDoubleToString(data.rotationRate.z)};
            SFEvent *event = [SFEvent eventWithType:SFMotionEventType path:nil fields:fields];
            event.time = data.timestamp * 1000.0;
            [[Sift sharedInstance] appendEvent:event];
        }];
    }

    if (_manager.magnetometerAvailable && !_manager.magnetometerActive) {
        SF_DEBUG(@"Start magnetometer");
        _manager.magnetometerUpdateInterval = interval;
        [_manager startMagnetometerUpdatesToQueue:_queue withHandler:^(CMMagnetometerData *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Magnetometer error: %@", [error localizedDescription]);
                [_manager stopMagnetometerUpdates];
                return;
            }
            NSDictionary *fields = @{@"raw_magnetic_field_x": SFDoubleToString(data.magneticField.x),
                                     @"raw_magnetic_field_y": SFDoubleToString(data.magneticField.y),
                                     @"raw_magnetic_field_z": SFDoubleToString(data.magneticField.z)};
            SFEvent *event = [SFEvent eventWithType:SFMotionEventType path:nil fields:fields];
            event.time = data.timestamp * 1000.0;
            [[Sift sharedInstance] appendEvent:event];
        }];
    }

    if (_manager.deviceMotionAvailable && !_manager.deviceMotionActive) {
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
        _manager.deviceMotionUpdateInterval = interval;
        [_manager startDeviceMotionUpdatesUsingReferenceFrame:frame toQueue:_queue withHandler:^(CMDeviceMotion *data, NSError *error) {
            if (error) {
                SF_DEBUG(@"Device motion error: %@", [error localizedDescription]);
                [_manager stopDeviceMotionUpdates];
                return;
            }
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
            SFEvent *event = [SFEvent eventWithType:SFMotionEventType path:nil fields:fields];
            event.time = data.timestamp * 1000.0;
            [[Sift sharedInstance] appendEvent:event];
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
