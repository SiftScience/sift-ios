// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"
#import "SFIosDeviceProperties.h"
#import "Sift.h"

#import "SFDevicePropertiesReporter.h"
#import "SFDevicePropertiesReporter+Notifications.h"

@implementation SFDevicePropertiesReporter (Notifications)

- (void)registerObservers {
    // If developer enables monitoring batter, orientation, and/or proximity sensor, we will receive those notification too.
    NSNotificationCenter *notification = [NSNotificationCenter defaultCenter];
    [notification addObserver:self selector:@selector(batteryLevelChanged:) name:UIDeviceBatteryLevelDidChangeNotification object:nil];
    [notification addObserver:self selector:@selector(batteryStateChanged:) name:UIDeviceBatteryStateDidChangeNotification object:nil];
    if (UIDevice.currentDevice.generatesDeviceOrientationNotifications) {
        [notification addObserver:self selector:@selector(orientationChanged:) name:UIDeviceOrientationDidChangeNotification object:nil];
    }
    [notification addObserver:self selector:@selector(proximityChanged:) name:UIDeviceProximityStateDidChangeNotification object:nil];
}

- (void)createEvent:(NSString *)name value:(id)value {
    SFIosDeviceProperties *properties = [SFIosDeviceProperties new];
    SFEvent *event = [SFEvent new];
    event.iosDeviceProperties = properties;
    [properties setProperty:name value:value];
    SF_DEBUG(@"Device property: %@ = %@", name, [properties.properties objectForKey:name]);
    [[Sift sharedInstance] appendEvent:event];
}

- (void)batteryLevelChanged:(NSNotification *)note {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }
    double level = UIDevice.currentDevice.batteryLevel;
    if (level < 0) {
        return;
    }
    [self createEvent:@"battery_level" value:[NSNumber numberWithDouble:level]];
}

- (void)batteryStateChanged:(NSNotification *)note {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }
    NSString *value = nil;
    switch (UIDevice.currentDevice.batteryState) {
        case UIDeviceBatteryStateUnknown: return;
#define CASE(enum_value) case enum_value: value = @#enum_value; break;
        CASE(UIDeviceBatteryStateUnplugged)
        CASE(UIDeviceBatteryStateCharging)
        CASE(UIDeviceBatteryStateFull)
#undef CASE
    }
    [self createEvent:@"battery_state" value:value];
}

- (void)orientationChanged:(NSNotification *)note {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }
    NSString *value = nil;
    switch (UIDevice.currentDevice.orientation) {
        case UIDeviceOrientationUnknown: return;
#define CASE(enum_value) case enum_value: value = @#enum_value; break;
        CASE(UIDeviceOrientationPortrait)
        CASE(UIDeviceOrientationPortraitUpsideDown)
        CASE(UIDeviceOrientationLandscapeLeft)
        CASE(UIDeviceOrientationLandscapeRight)
        CASE(UIDeviceOrientationFaceUp)
        CASE(UIDeviceOrientationFaceDown)
#undef CASE
    }
    [self createEvent:@"device_orientation" value:value];
}

- (void)proximityChanged:(NSNotification *)note {
    if (UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        return;
    }
    [self createEvent:@"proximity_state" value:[NSNumber numberWithBool:UIDevice.currentDevice.proximityState]];
}

@end
