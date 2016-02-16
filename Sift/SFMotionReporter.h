// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

typedef struct {
    BOOL readAccelerometer;
    NSTimeInterval accelerometerUpdateInterval;  // Unit: seconds.
    BOOL readGyroscope;
    NSTimeInterval gyroUpdateInterval;  // Unit: seconds.
    BOOL readMagnetometer;
    NSTimeInterval magnetometerUpdateInterval;  // Unit: seconds.
    BOOL readDeviceMotion;
    NSTimeInterval deviceMotionUpdateInterval;  // Unit: seconds.
} SFMotionReporterConfig;

@interface SFMotionReporter : NSObject

/**
 * Enable/disable motion collection.
 *
 * Default to NO.
 */
@property (nonatomic) BOOL enabled;

/** Start motion data collection. */
- (void)start:(SFMotionReporterConfig)config;
- (void)start;

/** Stop motion data collection. */
- (void)stop;

@end