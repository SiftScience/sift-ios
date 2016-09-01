// Copyright (c) 2016 Sift Science. All rights reserved.

#import "Sift/Sift.h"

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Configure Sift object here.

    // At minimum, you should configure these two.
    //[Sift sharedInstance].accountId = ...;
    //[Sift sharedInstance].beaconKey = ...;

    // In addition, if you have any queues, you should set up them here.
    //[[Sift sharedInstance] addEventQueue:... config:...];

    // During integration, you may set this URL to a RequestBin or a private server to validate that your integration works.
    //[Sift sharedInstance].serverUrlFormat = @"http://localhost:8080";

    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    UIDevice *device = [UIDevice currentDevice];

    device.batteryMonitoringEnabled = YES;
    if (!device.batteryMonitoringEnabled) {
        NSLog(@"Cannot monitor battery");
    }

    if (device.generatesDeviceOrientationNotifications) {
        [device beginGeneratingDeviceOrientationNotifications];
    }

    device.proximityMonitoringEnabled = YES;
    if (!device.proximityMonitoringEnabled) {
        NSLog(@"Cannot monitor proximity");
    }
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    UIDevice *device = [UIDevice currentDevice];

    device.batteryMonitoringEnabled = NO;

    if (device.generatesDeviceOrientationNotifications) {
        [device endGeneratingDeviceOrientationNotifications];
    }

    device.proximityMonitoringEnabled = NO;
}

@end
