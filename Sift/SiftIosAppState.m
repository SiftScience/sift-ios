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

NSMutableDictionary *SFMakeEmptyIosAppState() {
    return [NSMutableDictionary new];
}

NSMutableDictionary *SFMakeLocation() {
    return [NSMutableDictionary new];
}

NSMutableDictionary *SFMakeHeading() {
    return [NSMutableDictionary new];
}

NSMutableDictionary *SFMakeIosDeviceMotion() {
    return [NSMutableDictionary new];
}

NSMutableDictionary *SFMakeIosDeviceAccelerometerData() {
    return [NSMutableDictionary new];
}

NSMutableDictionary *SFMakeIosDeviceGyroData() {
    return [NSMutableDictionary new];
}

NSMutableDictionary *SFMakeIosDeviceMagnetometerData() {
    return [NSMutableDictionary new];
}

#pragma mark - Converters

NSDictionary *SFCMDeviceMotionToDictionary(CMDeviceMotion *data, SFTimestamp now) {
    NSMutableDictionary *dict = SFMakeIosDeviceMotion();
    [dict setValue:[NSNumber numberWithUnsignedLongLong:now] forKey:@"time"];
    [dict setValue:[NSNumber numberWithDouble:data.attitude.roll] forKey:@"attitude_roll"];
    [dict setValue:[NSNumber numberWithDouble:data.attitude.pitch] forKey:@"attitude_pitch"];
    [dict setValue:[NSNumber numberWithDouble:data.attitude.yaw] forKey:@"attitude_yaw"];
    [dict setValue:[NSNumber numberWithDouble:data.rotationRate.x] forKey:@"rotation_rate_x"];
    [dict setValue:[NSNumber numberWithDouble:data.rotationRate.y] forKey:@"rotation_rate_y"];
    [dict setValue:[NSNumber numberWithDouble:data.rotationRate.z] forKey:@"rotation_rate_z"];
    [dict setValue:[NSNumber numberWithDouble:data.gravity.x] forKey:@"gravity_x"];
    [dict setValue:[NSNumber numberWithDouble:data.gravity.y] forKey:@"gravity_y"];
    [dict setValue:[NSNumber numberWithDouble:data.gravity.z] forKey:@"gravity_z"];
    [dict setValue:[NSNumber numberWithDouble:data.userAcceleration.x] forKey:@"user_acceleration_x"];
    [dict setValue:[NSNumber numberWithDouble:data.userAcceleration.y] forKey:@"user_acceleration_y"];
    [dict setValue:[NSNumber numberWithDouble:data.userAcceleration.z] forKey:@"user_acceleration_z"];
    if (data.magneticField.accuracy != CMMagneticFieldCalibrationAccuracyUncalibrated) {
        [dict setValue:[NSNumber numberWithDouble:data.magneticField.field.x] forKey:@"magnetic_field_x"];
        [dict setValue:[NSNumber numberWithDouble:data.magneticField.field.y] forKey:@"magnetic_field_y"];
        [dict setValue:[NSNumber numberWithDouble:data.magneticField.field.z] forKey:@"magnetic_field_x"];
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
            [dict setValue:value forKey:@"magnetic_field_calibration_accuracy"];
        }
    }
    return dict;
}

NSDictionary *SFCMAccelerometerDataToDictionary(CMAccelerometerData *data, SFTimestamp now) {
    NSMutableDictionary *dict = SFMakeIosDeviceAccelerometerData();
    [dict setValue:[NSNumber numberWithUnsignedLongLong:now] forKey:@"time"];
    [dict setValue:[NSNumber numberWithDouble:data.acceleration.x] forKey:@"acceleration_x"];
    [dict setValue:[NSNumber numberWithDouble:data.acceleration.y] forKey:@"acceleration_y"];
    [dict setValue:[NSNumber numberWithDouble:data.acceleration.z] forKey:@"acceleration_z"];
    return dict;
}

NSDictionary *SFCMGyroDataToDictionary(CMGyroData *data, SFTimestamp now) {
    NSMutableDictionary *dict = SFMakeIosDeviceGyroData();
    [dict setValue:[NSNumber numberWithUnsignedLongLong:now] forKey:@"time"];
    [dict setValue:[NSNumber numberWithDouble:data.rotationRate.x] forKey:@"rotation_rate_x"];
    [dict setValue:[NSNumber numberWithDouble:data.rotationRate.y] forKey:@"rotation_rate_y"];
    [dict setValue:[NSNumber numberWithDouble:data.rotationRate.z] forKey:@"rotation_rate_z"];
    return dict;
}

NSDictionary *SFCMMagnetometerDataToDictionary(CMMagnetometerData *data, SFTimestamp now) {
    NSMutableDictionary *dict = SFMakeIosDeviceMagnetometerData();
    [dict setValue:[NSNumber numberWithUnsignedLongLong:now] forKey:@"time"];
    [dict setValue:[NSNumber numberWithDouble:data.magneticField.x] forKey:@"magnetic_field_x"];
    [dict setValue:[NSNumber numberWithDouble:data.magneticField.y] forKey:@"magnetic_field_y"];
    [dict setValue:[NSNumber numberWithDouble:data.magneticField.z] forKey:@"magnetic_field_z"];
    return dict;
}

#pragma mark - App state collection.

static SF_GENERICS(NSArray, NSString *) *getIpAddresses(void);

NSMutableDictionary *SFCollectIosAppState(CLLocationManager *locationManager, NSString *title) {
    NSMutableDictionary *iosAppState = SFMakeEmptyIosAppState();
    [iosAppState setValue:[Sift sharedInstance].sdkVersion forKey:@"sdk_version"];

    NSString *applicationState = nil;
    switch (UIApplication.sharedApplication.applicationState) {
#define CASE(enum_value) case enum_value: applicationState = SFCamelCaseToSnakeCase(@#enum_value); break;
        CASE(UIApplicationStateActive);
        CASE(UIApplicationStateInactive);
        CASE(UIApplicationStateBackground);
#undef CASE
    }
    if (applicationState) {
        [iosAppState setValue:applicationState forKey:@"application_state"];
    }

    if (title) {
        [iosAppState setValue:[[NSArray alloc] initWithObjects:title, nil] forKey:@"window_root_view_controller_titles"];
    }

    UIDevice *device = UIDevice.currentDevice;

    // Battery
    if (device.isBatteryMonitoringEnabled) {
        double batteryLevel = device.batteryLevel;
        if (batteryLevel >= 0) {
            [iosAppState setValue:[NSNumber numberWithDouble:batteryLevel] forKey:@"battery_level"];
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
            [iosAppState setValue:batteryState forKey:@"battery_state"];
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
            [iosAppState setValue:deviceOrientation forKey:@"device_orientation"];
        }
    }

    // Proximity
    if (device.isProximityMonitoringEnabled) {
        [iosAppState setValue:[NSNumber numberWithBool:device.proximityState] forKey:@"proximity_state"];
    }

    // Network
    [iosAppState setValue:getIpAddresses() forKey:@"network_addresses"];
    
    // Location data will be collected in SFIosAppStateCollector

    // Motion sensor data will be collected in SFIosAppStateCollector

    return iosAppState;
}

#pragma mark - Helper functions.

NSDictionary *SFCLLocationToDictionary(CLLocation *location) {
    NSMutableDictionary *dict = SFMakeLocation();
    [dict setValue:[NSNumber numberWithLongLong:(location.timestamp.timeIntervalSince1970 * 1000)] forKey:@"time"];
    
    if (location.horizontalAccuracy >= 0) {
        [dict setValue:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"latitude"];
        [dict setValue:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"longitude"];
        [dict setValue:[NSNumber numberWithDouble:location.horizontalAccuracy] forKey:@"horizontal_accuracy"];
    }
    if (location.verticalAccuracy >= 0) {
        [dict setValue:[NSNumber numberWithDouble:location.altitude] forKey:@"altitude"];
        [dict setValue:[NSNumber numberWithDouble:location.verticalAccuracy] forKey:@"vertical_accuracy"];
    }
    if (location.floor) {
        [dict setValue:[NSNumber numberWithInteger:location.floor.level] forKey:@"floor"];
    }
    if (location.speed >= 0) {
        [dict setValue:[NSNumber numberWithDouble:location.speed] forKey:@"speed"];
    }
    if (location.course >= 0) {
        [dict setValue:[NSNumber numberWithDouble:location.course] forKey:@"course"];
    }
    return dict;
}

NSDictionary *SFCLHeadingToDictionary(CLHeading *heading) {
    NSMutableDictionary *dict = SFMakeHeading();
    [dict setValue:[NSNumber numberWithLongLong:(heading.timestamp.timeIntervalSince1970 * 1000)] forKey:@"time"];
    if (heading.headingAccuracy >= 0) {
        [dict setValue:[NSNumber numberWithDouble:heading.magneticHeading] forKey:@"magnetic_heading"];
        [dict setValue:[NSNumber numberWithDouble:heading.headingAccuracy] forKey:@"accuracy"];
    }
    if (heading.trueHeading >= 0) {
        [dict setValue:[NSNumber numberWithDouble:heading.trueHeading] forKey:@"true_heading"];
    }
    [dict setValue:[NSNumber numberWithDouble:heading.x] forKey:@"raw_magnetic_field_x"];
    [dict setValue:[NSNumber numberWithDouble:heading.y] forKey:@"raw_magnetic_field_y"];
    [dict setValue:[NSNumber numberWithDouble:heading.z] forKey:@"raw_magnetic_field_z"];
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


