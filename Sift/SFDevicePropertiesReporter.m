// Copyright (c) 2015 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFDevicePropertiesReporter.h"

NSString * const SFDevicePropertiesReporterQueueIdentifier = @"sift-devprops";

static NSString * const SFDevicePropertiesReporterPath = @"/sift/device-properties";

const SFQueueConfig SFDevicePropertiesReporterQueueConfig = {
    .appendEventOnlyWhenDifferent = YES,
    .rotateWhenLargerThan = 4096,  // 4 KB
    .rotateWhenOlderThan = 3600,  // 1 hour
};

@implementation SFDevicePropertiesReporter

- (void)report {
    NSMutableDictionary *report = [NSMutableDictionary new];

    UIDevice *device = [UIDevice currentDevice];
    [report setObject:[[device identifierForVendor] UUIDString] forKey:@"identifier_for_vendor"];
    for (NSString *propertyName in @[@"name", @"systemName", @"systemVersion", @"model", @"localizedModel"]) {
        [report setObject:[device performSelector:NSSelectorFromString(propertyName)] forKey:SFCamelCaseToSnakeCase(propertyName)];
    }

    // TODO(clchiou): Gather more properties...

    SFDebug(@"Gather device properties: %@", report);
    [[Sift sharedSift] appendEvent:[SFEvent eventWithPath:SFDevicePropertiesReporterPath mobileEventType:nil userId:nil fields:report] toQueue:SFDevicePropertiesReporterQueueIdentifier];
}

@end