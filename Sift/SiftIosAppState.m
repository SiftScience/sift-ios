// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;
@import UIKit;

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>

#import "SiftCompatibility.h"
#import "SiftDebug.h"
#import "SiftUtils.h"

#import "Sift.h"
#import "SiftIosAppState.h"

SiftHtDictionary *SFMakeEmptyIosAppState() {
    static SF_GENERICS(NSMutableDictionary, NSString *, Class) *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])

        ENTRY_TYPE(@"application_state", NSString.class);
        ENTRY_TYPE(@"sdk_version",       NSString.class);

        ENTRY_TYPE(@"window_root_view_controller_titles", NSArray.class);

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
    return [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SiftHtDictionary *SFMakeLocation() {
    static SF_GENERICS(NSMutableDictionary, NSString *, Class) *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])
        
        ENTRY_TYPE(@"time", NSNumber.class);
        
        ENTRY_TYPE(@"latitude", NSNumber.class);
        ENTRY_TYPE(@"longitude", NSNumber.class);
        ENTRY_TYPE(@"altitude", NSNumber.class);
        ENTRY_TYPE(@"horizontal_accuracy", NSNumber.class);
        ENTRY_TYPE(@"vertical_accuracy", NSNumber.class);
        
        ENTRY_TYPE(@"floor", NSNumber.class);
        ENTRY_TYPE(@"speed", NSNumber.class);
        ENTRY_TYPE(@"course", NSNumber.class);
        
#undef ENTRY_TYPE
    });
    return [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SiftHtDictionary *SFMakeHeading() {
    static SF_GENERICS(NSMutableDictionary, NSString *, Class) *entryTypes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        entryTypes = [NSMutableDictionary new];
#define ENTRY_TYPE(key_, type_) ([entryTypes setObject:(type_) forKey:(key_)])

        ENTRY_TYPE(@"time", NSNumber.class);

        ENTRY_TYPE(@"magnetic_heading", NSNumber.class);
        ENTRY_TYPE(@"accuracy", NSNumber.class);

        ENTRY_TYPE(@"true_heading", NSNumber.class);

        ENTRY_TYPE(@"raw_magnetic_field_x", NSNumber.class);
        ENTRY_TYPE(@"raw_magnetic_field_y", NSNumber.class);
        ENTRY_TYPE(@"raw_magnetic_field_z", NSNumber.class);

#undef ENTRY_TYPE
    });
    return [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SiftHtDictionary *SFMakeIosDeviceMotion() {
    static SF_GENERICS(NSMutableDictionary, NSString *, Class) *entryTypes;
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
    return [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SiftHtDictionary *SFMakeIosDeviceAccelerometerData() {
    static SF_GENERICS(NSMutableDictionary, NSString *, Class) *entryTypes;
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
    return [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SiftHtDictionary *SFMakeIosDeviceGyroData() {
    static SF_GENERICS(NSMutableDictionary, NSString *, Class) *entryTypes;
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
    return [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
}

static SiftHtDictionary *SFMakeIosDeviceMagnetometerData() {
    static SF_GENERICS(NSMutableDictionary, NSString *, Class) *entryTypes;
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
    return [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
}

#pragma mark - Converters

SiftHtDictionary *SFCMDeviceMotionToDictionary(CMDeviceMotion *data, SFTimestamp now) {
    SiftHtDictionary *dict = SFMakeIosDeviceMotion();
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
#define CASE(enum_value) case enum_value: value = SFCamelCaseToSnakeCase(@#enum_value); break;
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

SiftHtDictionary *SFCMAccelerometerDataToDictionary(CMAccelerometerData *data, SFTimestamp now) {
    SiftHtDictionary *dict = SFMakeIosDeviceAccelerometerData();
    [dict setEntry:@"time" value:[NSNumber numberWithUnsignedLongLong:now]];
    [dict setEntry:@"acceleration_x" value:[NSNumber numberWithDouble:data.acceleration.x]];
    [dict setEntry:@"acceleration_y" value:[NSNumber numberWithDouble:data.acceleration.y]];
    [dict setEntry:@"acceleration_z" value:[NSNumber numberWithDouble:data.acceleration.z]];
    return dict;
}

SiftHtDictionary *SFCMGyroDataToDictionary(CMGyroData *data, SFTimestamp now) {
    SiftHtDictionary *dict = SFMakeIosDeviceGyroData();
    [dict setEntry:@"time" value:[NSNumber numberWithUnsignedLongLong:now]];
    [dict setEntry:@"rotation_rate_x" value:[NSNumber numberWithDouble:data.rotationRate.x]];
    [dict setEntry:@"rotation_rate_y" value:[NSNumber numberWithDouble:data.rotationRate.y]];
    [dict setEntry:@"rotation_rate_z" value:[NSNumber numberWithDouble:data.rotationRate.z]];
    return dict;
}

SiftHtDictionary *SFCMMagnetometerDataToDictionary(CMMagnetometerData *data, SFTimestamp now) {
    SiftHtDictionary *dict = SFMakeIosDeviceMagnetometerData();
    [dict setEntry:@"time" value:[NSNumber numberWithUnsignedLongLong:now]];
    [dict setEntry:@"magnetic_field_x" value:[NSNumber numberWithDouble:data.magneticField.x]];
    [dict setEntry:@"magnetic_field_y" value:[NSNumber numberWithDouble:data.magneticField.y]];
    [dict setEntry:@"magnetic_field_z" value:[NSNumber numberWithDouble:data.magneticField.z]];
    return dict;
}

#pragma mark - App state collection.

static SF_GENERICS(NSArray, NSString *) *getIpAddresses(void);

SiftHtDictionary *SFCollectIosAppState(CLLocationManager *locationManager, NSString *title) {
    SiftHtDictionary *iosAppState = SFMakeEmptyIosAppState();
    
    [iosAppState setEntry:@"sdk_version" value:[Sift sharedInstance].sdkVersion];

    NSString *applicationState = nil;
    switch (UIApplication.sharedApplication.applicationState) {
#define CASE(enum_value) case enum_value: applicationState = SFCamelCaseToSnakeCase(@#enum_value); break;
        CASE(UIApplicationStateActive);
        CASE(UIApplicationStateInactive);
        CASE(UIApplicationStateBackground);
#undef CASE
    }
    if (applicationState) {
        [iosAppState setEntry:@"application_state" value:applicationState];
    }

    if (title) {
        [iosAppState setEntry:@"window_root_view_controller_titles"
                        value:[[NSArray alloc] initWithObjects:title, nil]];
    }

    UIDevice *device = UIDevice.currentDevice;

    // Battery
    if (device.isBatteryMonitoringEnabled) {
        double batteryLevel = device.batteryLevel;
        if (batteryLevel >= 0) {
            [iosAppState setEntry:@"battery_level" value:[NSNumber numberWithDouble:batteryLevel]];
        }
        NSString *batteryState = nil;
        switch (device.batteryState) {
#define CASE(enum_value) case enum_value: batteryState = SFCamelCaseToSnakeCase(@#enum_value); break;
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
#define CASE(enum_value) case enum_value: deviceOrientation = SFCamelCaseToSnakeCase(@#enum_value); break;
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

    // Network
    [iosAppState setEntry:@"network_addresses" value:getIpAddresses()];
    
    // Location data will be collected in SFIosAppStateCollector

    // Motion sensor data will be collected in SFIosAppStateCollector

    return iosAppState;
}

#pragma mark - Helper functions.

SiftHtDictionary *SFCLLocationToDictionary(CLLocation *location) {
    SiftHtDictionary *dict = SFMakeLocation();
    [dict setEntry:@"time" value:[NSNumber numberWithLongLong:(location.timestamp.timeIntervalSince1970 * 1000)]];
    
    if (location.horizontalAccuracy >= 0) {
        [dict setEntry:@"latitude" value:[NSNumber numberWithDouble:location.coordinate.latitude]];
        [dict setEntry:@"longitude" value:[NSNumber numberWithDouble:location.coordinate.longitude]];
        [dict setEntry:@"horizontal_accuracy" value:[NSNumber numberWithDouble:location.horizontalAccuracy]];
    }
    if (location.verticalAccuracy >= 0) {
        [dict setEntry:@"altitude" value:[NSNumber numberWithDouble:location.altitude]];
        [dict setEntry:@"vertical_accuracy" value:[NSNumber numberWithDouble:location.verticalAccuracy]];
    }
    if (location.floor) {
        [dict setEntry:@"floor" value:[NSNumber numberWithInteger:location.floor.level]];
    }
    if (location.speed >= 0) {
        [dict setEntry:@"speed" value:[NSNumber numberWithDouble:location.speed]];
    }
    if (location.course >= 0) {
        [dict setEntry:@"course" value:[NSNumber numberWithDouble:location.course]];
    }
    return dict;
}

SiftHtDictionary *SFCLHeadingToDictionary(CLHeading *heading) {
    SiftHtDictionary *dict = SFMakeHeading();
    [dict setEntry:@"time" value:[NSNumber numberWithLongLong:(heading.timestamp.timeIntervalSince1970 * 1000)]];
    if (heading.headingAccuracy >= 0) {
        [dict setEntry:@"magnetic_heading" value:[NSNumber numberWithDouble:heading.magneticHeading]];
        [dict setEntry:@"accuracy" value:[NSNumber numberWithDouble:heading.headingAccuracy]];
    }
    if (heading.trueHeading >= 0) {
        [dict setEntry:@"true_heading" value:[NSNumber numberWithDouble:heading.trueHeading]];
    }
    [dict setEntry:@"raw_magnetic_field_x" value:[NSNumber numberWithDouble:heading.x]];
    [dict setEntry:@"raw_magnetic_field_y" value:[NSNumber numberWithDouble:heading.y]];
    [dict setEntry:@"raw_magnetic_field_z" value:[NSNumber numberWithDouble:heading.z]];
    return dict;
}

static SF_GENERICS(NSArray, NSString *) *getIpAddresses() {
    struct ifaddrs *interfaces;
    if (getifaddrs(&interfaces)) {
        SF_DEBUG(@"Cannot get network interface: %s", strerror(errno));
        return nil;
    }

    SF_GENERICS(NSMutableArray, NSString *) *addresses = [NSMutableArray new];
    for (struct ifaddrs *interface = interfaces; interface; interface = interface->ifa_next) {
        if (!(interface->ifa_flags & IFF_UP)) {
            continue;  // Skip interfaces that are down.
        }
        if (interface->ifa_flags & IFF_LOOPBACK) {
            continue;  // Skip loopback interface.
        }
        
        // Validate an IP address
        int success = 0;
        NSString *addressStr = @"error";
        addressStr = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)interface->ifa_addr)->sin_addr)];
        const char *utf8 = [addressStr UTF8String];
        struct in_addr dst;
        success = inet_pton(AF_INET, utf8, &dst);
        if (success != 1) {
            struct in6_addr dst6;
            success = inet_pton(AF_INET6, utf8, &dst6);
        }
        
        if(success == 1) {
            if (interface->ifa_addr->sa_family == (uint8_t)(AF_INET)) {
                const struct sockaddr_in *address = (const struct sockaddr_in*)interface->ifa_addr;
                if (!address) {
                    continue;  // Skip interfaces that have no address.
                }
                SF_DEBUG(@"Read address from interface: %s", interface->ifa_name);
                 
                uint32_t ip = ntohl(address->sin_addr.s_addr);
                in_addr_t addr = htonl(ip);
                struct in_addr ip_addr;
                ip_addr.s_addr = addr;
                NSString *ipv4_address = [NSString stringWithUTF8String: inet_ntoa(ip_addr)];
                [addresses addObject: ipv4_address];
            } else if (interface->ifa_addr->sa_family == (uint8_t)(AF_INET6)) {
                const struct sockaddr_in6 *address = (const struct sockaddr_in6*)interface->ifa_addr;
                if (!address) {
                    continue;  // Skip interfaces that have no address.
                }
                SF_DEBUG(@"Read address from interface: %s", interface->ifa_name);
                char address_buffer[INET6_ADDRSTRLEN];
                if (!inet_ntop(AF_INET6, &address->sin6_addr, address_buffer, INET6_ADDRSTRLEN)) {
                    SF_DEBUG(@"Cannot convert INET6 address: %s", strerror(errno));
                    continue;
                }
                [addresses addObject:[NSString stringWithUTF8String:address_buffer]];
            } else {
                continue;  // Skip non-IPv4 and non-IPv6 interface.
            }
        }
    }
    free(interfaces);

    return addresses;
}


