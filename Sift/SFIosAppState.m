// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;
@import UIKit;

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>

#import "SFDebug.h"

#import "SFIosAppState.h"

SFHtDictionary *SFMakeEmptyIosAppState() {
    static NSMutableDictionary<NSString *, Class> *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])

        ENTRY_TYPE(@"battery_level", NSNumber.class);
        ENTRY_TYPE(@"battery_state", NSString.class);

        ENTRY_TYPE(@"device_orientation", NSString.class);

        ENTRY_TYPE(@"proximity_state", NSNumber.class);

        ENTRY_TYPE(@"location", NSDictionary.class);
        ENTRY_TYPE(@"heading",  NSDictionary.class);

        ENTRY_TYPE(@"network_addresses", NSArray.class);

        ENTRY_TYPE(@"motion",            NSArray.class);
        ENTRY_TYPE(@"raw_accelerometer", NSArray.class);
        ENTRY_TYPE(@"raw_gyro",          NSArray.class);
        ENTRY_TYPE(@"raw_magnetometer",  NSArray.class);

#undef ENTRY_TYPE
    });
    return [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SFHtDictionary *SFMakeIosDeviceMotion() {
    static NSMutableDictionary<NSString *, Class> *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])

        ENTRY_TYPE(@"time", NSNumber.class);

        ENTRY_TYPE(@"attitude_roll",  NSNumber.class);
        ENTRY_TYPE(@"attitude_pitch", NSNumber.class);
        ENTRY_TYPE(@"attitude_yaw",   NSNumber.class);

        ENTRY_TYPE(@"rotation_rate_x", NSNumber.class);
        ENTRY_TYPE(@"rotation_rate_y", NSNumber.class);
        ENTRY_TYPE(@"rotation_rate_z", NSNumber.class);

        ENTRY_TYPE(@"gravity_x", NSNumber.class);
        ENTRY_TYPE(@"gravity_y", NSNumber.class);
        ENTRY_TYPE(@"gravity_z", NSNumber.class);

        ENTRY_TYPE(@"user_acceleration_x", NSNumber.class);
        ENTRY_TYPE(@"user_acceleration_y", NSNumber.class);
        ENTRY_TYPE(@"user_acceleration_z", NSNumber.class);

        ENTRY_TYPE(@"magnetic_field_x", NSNumber.class);
        ENTRY_TYPE(@"magnetic_field_y", NSNumber.class);
        ENTRY_TYPE(@"magnetic_field_z", NSNumber.class);
        ENTRY_TYPE(@"magnetic_field_calibration_accuracy", NSString.class);

#undef ENTRY_TYPE
    });
    return [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SFHtDictionary *SFMakeIosDeviceAccelerometerData() {
    static NSMutableDictionary<NSString *, Class> *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])

        ENTRY_TYPE(@"time", NSNumber.class);

        ENTRY_TYPE(@"acceleration_x", NSNumber.class);
        ENTRY_TYPE(@"acceleration_y", NSNumber.class);
        ENTRY_TYPE(@"acceleration_z", NSNumber.class);

#undef ENTRY_TYPE
    });
    return [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SFHtDictionary *SFMakeIosDeviceGyroData() {
    static NSMutableDictionary<NSString *, Class> *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])

        ENTRY_TYPE(@"time", NSNumber.class);

        ENTRY_TYPE(@"rotation_rate_x", NSNumber.class);
        ENTRY_TYPE(@"rotation_rate_y", NSNumber.class);
        ENTRY_TYPE(@"rotation_rate_z", NSNumber.class);

#undef ENTRY_TYPE
    });
    return [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SFHtDictionary *SFMakeIosDeviceMagnetometerData() {
    static NSMutableDictionary<NSString *, Class> *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])

        ENTRY_TYPE(@"time", NSNumber.class);

        ENTRY_TYPE(@"magnetic_field_x", NSNumber.class);
        ENTRY_TYPE(@"magnetic_field_y", NSNumber.class);
        ENTRY_TYPE(@"magnetic_field_z", NSNumber.class);

#undef ENTRY_TYPE
    });
    return [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
}

#pragma mark - Converters

SFHtDictionary *SFCMDeviceMotionToDictionary(CMDeviceMotion *data, SFTimestamp now) {
    SFHtDictionary *dict = SFMakeIosDeviceMotion();
    [dict setEntry:@"time" value:[NSNumber numberWithUnsignedLongLong:now]];
    [dict setEntry:@"attitude_roll" value:[NSNumber numberWithDouble:data.attitude.roll]];
    [dict setEntry:@"attitude_pitch" value:[NSNumber numberWithDouble:data.attitude.pitch]];
    [dict setEntry:@"attitude_yaw" value:[NSNumber numberWithDouble:data.attitude.yaw]];
    [dict setEntry:@"rotation_rate_x" value:[NSNumber numberWithDouble:data.rotationRate.x]];
    [dict setEntry:@"rotation_rate_y" value:[NSNumber numberWithDouble:data.rotationRate.y]];
    [dict setEntry:@"rotation_rate_z" value:[NSNumber numberWithDouble:data.rotationRate.z]];
    [dict setEntry:@"gravity_x" value:[NSNumber numberWithDouble:data.gravity.x]];
    [dict setEntry:@"gravity_y" value:[NSNumber numberWithDouble:data.gravity.y]];
    [dict setEntry:@"gravity_z" value:[NSNumber numberWithDouble:data.gravity.z]];
    [dict setEntry:@"user_acceleration_x" value:[NSNumber numberWithDouble:data.userAcceleration.x]];
    [dict setEntry:@"user_acceleration_y" value:[NSNumber numberWithDouble:data.userAcceleration.y]];
    [dict setEntry:@"user_acceleration_z" value:[NSNumber numberWithDouble:data.userAcceleration.z]];
    if (data.magneticField.accuracy != CMMagneticFieldCalibrationAccuracyUncalibrated) {
        [dict setEntry:@"magnetic_field_x" value:[NSNumber numberWithDouble:data.magneticField.field.x]];
        [dict setEntry:@"magnetic_field_y" value:[NSNumber numberWithDouble:data.magneticField.field.y]];
        [dict setEntry:@"magnetic_field_z" value:[NSNumber numberWithDouble:data.magneticField.field.z]];
        NSString *value = nil;
        switch (data.magneticField.accuracy) {
#define CASE(enum_value) case enum_value: value = @#enum_value; break;
            CASE(CMMagneticFieldCalibrationAccuracyUncalibrated);
            CASE(CMMagneticFieldCalibrationAccuracyLow);
            CASE(CMMagneticFieldCalibrationAccuracyMedium);
            CASE(CMMagneticFieldCalibrationAccuracyHigh);
#undef CASE
        }
        if (value) {
            [dict setEntry:@"magnetic_field_calibration_accuracy" value:value];
        }
    }
    return dict;
}

SFHtDictionary *SFCMAccelerometerDataToDictionary(CMAccelerometerData *data, SFTimestamp now) {
    SFHtDictionary *dict = SFMakeIosDeviceAccelerometerData();
    [dict setEntry:@"time" value:[NSNumber numberWithUnsignedLongLong:now]];
    [dict setEntry:@"acceleration_x" value:[NSNumber numberWithDouble:data.acceleration.x]];
    [dict setEntry:@"acceleration_y" value:[NSNumber numberWithDouble:data.acceleration.y]];
    [dict setEntry:@"acceleration_z" value:[NSNumber numberWithDouble:data.acceleration.z]];
    return dict;
}

SFHtDictionary *SFCMGyroDataToDictionary(CMGyroData *data, SFTimestamp now) {
    SFHtDictionary *dict = SFMakeIosDeviceGyroData();
    [dict setEntry:@"time" value:[NSNumber numberWithUnsignedLongLong:now]];
    [dict setEntry:@"rotation_rate_x" value:[NSNumber numberWithDouble:data.rotationRate.x]];
    [dict setEntry:@"rotation_rate_y" value:[NSNumber numberWithDouble:data.rotationRate.y]];
    [dict setEntry:@"rotation_rate_z" value:[NSNumber numberWithDouble:data.rotationRate.z]];
    return dict;
}

SFHtDictionary *SFCMMagnetometerDataToDictionary(CMMagnetometerData *data, SFTimestamp now) {
    SFHtDictionary *dict = SFMakeIosDeviceMagnetometerData();
    [dict setEntry:@"time" value:[NSNumber numberWithUnsignedLongLong:now]];
    [dict setEntry:@"magnetic_field_x" value:[NSNumber numberWithDouble:data.magneticField.x]];
    [dict setEntry:@"magnetic_field_y" value:[NSNumber numberWithDouble:data.magneticField.y]];
    [dict setEntry:@"magnetic_field_z" value:[NSNumber numberWithDouble:data.magneticField.z]];
    return dict;
}

#pragma mark - App state collection.

static NSDictionary *locationToDictionary(CLLocation *location);
static NSDictionary *headingToDictionary(CLHeading *heading);
static NSArray<NSString *> *getIpAddresses();

SFHtDictionary *SFCollectIosAppState(CLLocationManager *locationManager) {
    SFHtDictionary *iosAppState = SFMakeEmptyIosAppState();

    UIDevice *device = UIDevice.currentDevice;

    // Battery
    if (device.isBatteryMonitoringEnabled) {
        double batteryLevel = device.batteryLevel;
        if (batteryLevel >= 0) {
            [iosAppState setEntry:@"battery_level" value:[NSNumber numberWithDouble:batteryLevel]];
        }
        NSString *batteryState = nil;
        switch (device.batteryState) {
#define CASE(enum_value) case enum_value: batteryState = @#enum_value; break;
            CASE(UIDeviceBatteryStateUnknown);
            CASE(UIDeviceBatteryStateUnplugged);
            CASE(UIDeviceBatteryStateCharging);
            CASE(UIDeviceBatteryStateFull);
#undef CASE
        }
        if (batteryState) {
            [iosAppState setEntry:@"battery_state" value:batteryState];
        }
    }

    // Orientation
    if (device.isGeneratingDeviceOrientationNotifications) {
        NSString *deviceOrientation = nil;
        switch (device.orientation) {
#define CASE(enum_value) case enum_value: deviceOrientation = @#enum_value; break;
            CASE(UIDeviceOrientationUnknown);
            CASE(UIDeviceOrientationPortrait);
            CASE(UIDeviceOrientationPortraitUpsideDown);
            CASE(UIDeviceOrientationLandscapeLeft);
            CASE(UIDeviceOrientationLandscapeRight);
            CASE(UIDeviceOrientationFaceUp);
            CASE(UIDeviceOrientationFaceDown);
#undef CASE
        }
        if (deviceOrientation) {
            [iosAppState setEntry:@"device_orientation" value:deviceOrientation];
        }
    }

    // Proximity
    if (device.isProximityMonitoringEnabled) {
        [iosAppState setEntry:@"proximity_state" value:[NSNumber numberWithBool:device.proximityState]];
    }

    // Location
    if (CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedAlways ||
        CLLocationManager.authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse) {
        if (locationManager.location) {
            [iosAppState setEntry:@"location" value:locationToDictionary(locationManager.location)];
        }
    }

    // Heading
    if (locationManager.heading) {
        [iosAppState setEntry:@"heading" value:headingToDictionary(locationManager.heading)];
    }

    // Network
    [iosAppState setEntry:@"network_addresses" value:getIpAddresses()];

    // Motion sensor data will be collected in other method.

    return iosAppState;
}

#pragma mark - Helper functions.

static NSDictionary *locationToDictionary(CLLocation *location) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"time"] = [NSNumber numberWithLongLong:(location.timestamp.timeIntervalSince1970 * 1000)];
    if (location.horizontalAccuracy >= 0) {
        dict[@"latitude"] = [NSNumber numberWithDouble:location.coordinate.latitude];
        dict[@"longitude"] = [NSNumber numberWithDouble:location.coordinate.longitude];
        dict[@"horizontal_accuracy"] = [NSNumber numberWithDouble:location.horizontalAccuracy];
    }
    if (location.verticalAccuracy >= 0) {
        dict[@"altitude"] = [NSNumber numberWithDouble:location.altitude];
        dict[@"vertical_accuracy"] = [NSNumber numberWithDouble:location.verticalAccuracy];
    }
    if (location.floor) {
        dict[@"floor"] = [NSNumber numberWithInteger:location.floor.level];
    }
    if (location.speed >= 0) {
        dict[@"speed"] = [NSNumber numberWithDouble:location.speed];
    }
    if (location.course >= 0) {
        dict[@"course"] = [NSNumber numberWithDouble:location.course];
    }
    return dict;
}

static NSDictionary *headingToDictionary(CLHeading *heading) {
    NSMutableDictionary *dict = [NSMutableDictionary new];
    dict[@"time"] = [NSNumber numberWithLongLong:(heading.timestamp.timeIntervalSince1970 * 1000)];
    if (heading.headingAccuracy >= 0) {
        dict[@"magnetic_heading"] = [NSNumber numberWithDouble:heading.magneticHeading];
        dict[@"accuracy"] = [NSNumber numberWithDouble:heading.headingAccuracy];
    }
    if (heading.trueHeading >= 0) {
        dict[@"true_heading"] = [NSNumber numberWithDouble:heading.trueHeading];
    }
    dict[@"raw_magnetic_field_x"] = [NSNumber numberWithDouble:heading.x];
    dict[@"raw_magnetic_field_y"] = [NSNumber numberWithDouble:heading.y];
    dict[@"raw_magnetic_field_z"] = [NSNumber numberWithDouble:heading.z];
    return dict;
}

static NSArray<NSString *> *getIpAddresses() {
    struct ifaddrs *interfaces;
    if (getifaddrs(&interfaces)) {
        SF_DEBUG(@"Cannot get network interface: %s", strerror(errno));
        return nil;
    }

    NSMutableArray<NSString *> *addresses = [NSMutableArray new];
    for (struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
        if (!(interface->ifa_flags & IFF_UP)) {
            continue;  // Skip interfaces that are down.
        }
        if (interface->ifa_flags & IFF_LOOPBACK) {
            continue;  // Skip loopback interface.
        }

        const struct sockaddr_in *address = (const struct sockaddr_in*)interface->ifa_addr;
        if (!address) {
            continue;  // Skip interfaces that have no address.
        }

        SF_DEBUG(@"Read address from interface: %s", interface->ifa_name);
        char address_buffer[MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN)];
        if (address->sin_family == AF_INET) {
            if (!inet_ntop(AF_INET, &address->sin_addr, address_buffer, INET_ADDRSTRLEN)) {
                SF_DEBUG(@"Cannot convert INET address: %s", strerror(errno));
                continue;
            }
        } else if (address->sin_family == AF_INET6) {
            const struct sockaddr_in6 *address_inet6 = (const struct sockaddr_in6*)interface->ifa_addr;
            if (!inet_ntop(AF_INET6, &address_inet6->sin6_addr, address_buffer, INET6_ADDRSTRLEN)) {
                SF_DEBUG(@"Cannot convert INET6 address: %s", strerror(errno));
                continue;
            }
        } else {
            continue;  // Skip non-IPv4 and non-IPv6 interface.
        }

        [addresses addObject:[NSString stringWithUTF8String:address_buffer]];
    }

    free(interfaces);

    return addresses;
}
