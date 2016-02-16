// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;

/** Control the behavior of an `SFLocationReporter`. */
typedef struct {
    BOOL useStandardLocationService;
    /** The distance filter of the standard location service. */
    CLLocationDistance distanceFilter;  // Unit: meters.

    CLLocationDegrees headingFilter;  // Unit: degrees.

    /** These configurations will be applied when deferred location updates are available. */
    struct {
        CLLocationDistance distance;  // Unit: meters.
        NSTimeInterval timeout;  // Unit: seconds.
    } deferredLocationUpdates;

} SFLocationReporterConfig;

@interface SFLocationReporter : NSObject<CLLocationManagerDelegate>

/**
 * Enable/disable location collection.
 *
 * Default to NO.
 */
@property (nonatomic) BOOL enabled;

/**
 * Start background location collection with the last config you set.
 *
 * @return YES if we are permitted to do so.
 */
- (BOOL)start;

/**
 * Start background location collection.
 *
 * @return YES if we are permitted to do so.
 */
- (BOOL)start:(SFLocationReporterConfig)config;

/** Stop background location collection. */
- (void)stop;

@end