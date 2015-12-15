// Copyright (c) 2015 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFDevicePropertiesReporter.h"

NSString * const SFDevicePropertiesReporterQueueIdentifier = @"sift-devprops";

const SFQueueConfig SFDevicePropertiesReporterQueueConfig = {
    .appendEventOnlyWhenDifferent = YES,
    .rotateWhenLargerThan = 4096,  // 4 KB
    .rotateWhenOlderThan = 60,  // 1 minute
};

@implementation SFDevicePropertiesReporter

- (NSDictionary *)createReport {
    NSMutableDictionary *report = [NSMutableDictionary new];

    UIDevice *device = [UIDevice currentDevice];
    [report setObject:[[device identifierForVendor] UUIDString] forKey:@"identifier_for_vendor"];
    for (NSString *propertyName in @[@"name", @"systemName", @"systemVersion", @"model", @"localizedModel"]) {
        SEL selector = NSSelectorFromString(propertyName);
        NSString *(*func)(id, SEL) = (void *)[device methodForSelector:selector];
        NSString *property = [NSString stringWithString:func(device, selector)];
        [report setObject:property forKey:SFCamelCaseToSnakeCase(propertyName)];
    }

    // TODO(clchiou): Gather more properties...

    SF_DEBUG(@"Device properties: %@", report);
    return report;
}

- (void)report {
    SFEvent *event = [SFEvent new];
    event.deviceProperties = [self createReport];
    [[Sift sharedInstance] appendEvent:event toQueue:SFDevicePropertiesReporterQueueIdentifier];
}

@end
