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

NSMutableDictionary *SFMakeEmptyIosAppState(void) {
    return [NSMutableDictionary new];
}

NSMutableDictionary *SFMakeLocation(void) {
    return [NSMutableDictionary new];
}

#pragma mark - App state collection.

static SF_GENERICS(NSArray, NSString *) *getIpAddresses(void);

NSMutableDictionary *SFCollectIosAppState(CLLocationManager *locationManager, NSString *title) {
    NSMutableDictionary *iosAppState = SFMakeEmptyIosAppState();
    [iosAppState setValue:[Sift sharedInstance].sdkVersion forKey:@"sdk_version"];

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
    
    if (location.horizontalAccuracy >= 0) {
        [dict setValue:[NSNumber numberWithDouble:location.coordinate.latitude] forKey:@"latitude"];
        [dict setValue:[NSNumber numberWithDouble:location.coordinate.longitude] forKey:@"longitude"];
    }
    return dict;
}

static SF_GENERICS(NSArray, NSString *) *getIpAddresses(void) {
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


