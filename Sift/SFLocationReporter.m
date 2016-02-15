// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFLocationReporter.h"
#import "SFUtils.h"
#import "Sift.h"

static NSString * const SFLocationEventType = @"$location";
static NSString * const SFLocationHeadingEventType = @"$location_heading";

static const SFLocationReporterConfig SFDefaultLocationReporterConfig = {
    .useStandardLocationService = YES,
    .distanceFilter = 10,
    .headingFilter = 30,
    .deferredLocationUpdates = {
        .distance = 100,
        .timeout = 60,
    },
};

@implementation SFLocationReporter {
    CLLocationManager *_manager;
    BOOL _started;
    SFLocationReporterConfig _config;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _manager = [CLLocationManager new];
        if (!_manager) {
            self = nil;
            return nil;
        }

        _started = NO;
        _config = SFDefaultLocationReporterConfig;

        _manager.delegate = self;
    }
    return self;
}

- (BOOL)start:(SFLocationReporterConfig)config {
    _config = config;
    return [self start];
}

- (BOOL)start {
    if (_started) {
        SF_DEBUG(@"Started already");
        return NO;
    }

    // Start location service _ONLY_ if we've already been granted to do so.
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status != kCLAuthorizationStatusAuthorizedAlways && status != kCLAuthorizationStatusAuthorizedWhenInUse) {
        SF_DEBUG("User did not (yet?) authorize us to use location: status=%d", status);
        return NO;
    }

    if (![CLLocationManager locationServicesEnabled]) {
        SF_DEBUG("Location service is disabled");
        return NO;
    }

    SF_DEBUG(@"Start location reporting");

    // TODO(clchiou): Should we set `desiredAccuracy` and `activityType` to non-default value?

    if (!_config.useStandardLocationService && [CLLocationManager significantLocationChangeMonitoringAvailable]) {
        // This saves more power than the standard location service.
        SF_DEBUG(@"Start significant location change service");
        [_manager startMonitoringSignificantLocationChanges];
    } else {
        SF_DEBUG(@"Start standard location service");
        _manager.distanceFilter = _config.distanceFilter;
        [_manager startUpdatingLocation];
    }

    if ([CLLocationManager headingAvailable]) {
        SF_DEBUG(@"Start heading updates");
        _manager.headingFilter = _config.headingFilter;
        [_manager startUpdatingHeading];
    }

    _started = YES;
    return YES;
}

- (void)stop {
    if(!_started) {
        SF_DEBUG(@"Not started yet");
        return;
    }

    SF_DEBUG(@"Stop location reporting");

    if (!_config.useStandardLocationService && [CLLocationManager significantLocationChangeMonitoringAvailable]) {
        SF_DEBUG(@"Stop significant location change service");
        [_manager stopMonitoringSignificantLocationChanges];
    } else {
        SF_DEBUG(@"Stop standard location service");
        [_manager stopUpdatingLocation];
    }

    if ([CLLocationManager headingAvailable]) {
        [_manager stopUpdatingHeading];
    }

    _started = NO;
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        if (!_started) {
            [self start];
        }
    } else {
        if (_started) {
            [self stop];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if (error.code == kCLErrorDenied) {
        SF_DEBUG(@"Been denied to use location service");
        [self stop];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    SF_DEBUG(@"Location udpated");
    Sift *sift = [Sift sharedInstance];
    for (CLLocation *location in locations) {
        NSMutableDictionary *fields = [NSMutableDictionary new];
        if (location.horizontalAccuracy >= 0) {
            fields[@"latitude"] = SFDoubleToString(location.coordinate.latitude);
            fields[@"longitude"] = SFDoubleToString(location.coordinate.longitude);
            fields[@"horizontal_accuracy"] = SFDoubleToString(location.horizontalAccuracy);
        }
        if (location.verticalAccuracy >= 0) {
            fields[@"altitude"] = SFDoubleToString(location.altitude);
            fields[@"vertical_accuracy"] = SFDoubleToString(location.verticalAccuracy);
        }
        if (location.floor) {
            fields[@"floor"] = [NSNumber numberWithLong:location.floor.level].stringValue;
        }
        if (location.speed >= 0) {
            fields[@"speed"] = SFDoubleToString(location.speed);
        }
        if (location.course >= 0) {
            fields[@"course"] = SFDoubleToString(location.course);
        }
        SFEvent *event = [SFEvent eventWithPath:nil mobileEventType:SFLocationEventType userId:sift.userId fields:fields];
        event.time = [location.timestamp timeIntervalSince1970] * 1000.0;
        [sift appendEvent:event];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading {
    SF_DEBUG(@"Heading udpated");
    Sift *sift = [Sift sharedInstance];
    NSMutableDictionary *fields = [NSMutableDictionary new];
    if (heading.headingAccuracy >= 0) {
        fields[@"magnetic_heading"] = SFDoubleToString(heading.magneticHeading);
        fields[@"heading_accuracy"] = SFDoubleToString(heading.headingAccuracy);
    }
    if (heading.trueHeading >= 0) {
        fields[@"true_heading"] = SFDoubleToString(heading.trueHeading);
    }
    fields[@"magnetic_field_x"] = SFDoubleToString(heading.x);
    fields[@"magnetic_field_y"] = SFDoubleToString(heading.y);
    fields[@"magnetic_field_z"] = SFDoubleToString(heading.z);
    SFEvent *event = [SFEvent eventWithPath:nil mobileEventType:SFLocationHeadingEventType userId:sift.userId fields:fields];
    event.time = [heading.timestamp timeIntervalSince1970] * 1000.0;
    [sift appendEvent:event];
}

@end