// Copyright (c) 2015 Sift Science. All rights reserved.

@import AdSupport;
@import CoreTelephony;
@import Foundation;
@import UIKit;

#include <sys/types.h>
#include <sys/sysctl.h>

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

static NSString *SFSysctlReadString(const char *name) {
    int err;
    size_t size;
    err = sysctlbyname(name, NULL, &size, NULL, 0);
    if (err) {
        SF_DEBUG(@"sysctlbyname(\"%s\", ...): %s", name, strerror(errno));
        return nil;
    }

    NSString *value = nil;
    char buffer[64];
    void *buf = size < sizeof(buffer) ? buffer : malloc(size);
    err = sysctlbyname(name, buf, &size, NULL, 0);
    if (err) {
        SF_DEBUG(@"sysctlbyname(\"%s\", ...): %s", name, strerror(errno));
    } else {
        value = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
    }
    if (buf != buffer) {
        free(buf);
    }
    return value;
}

static NSString *SFSysctlReadUInt32(const char *name) {
    uint32_t value;
    size_t size = sizeof(value);
    int err = sysctlbyname(name, &value, &size, NULL, 0);
    if (err) {
        SF_DEBUG(@"sysctlbyname(\"%s\", ...): %s", name, strerror(errno));
        return nil;
    } else {
        return [NSString stringWithFormat:@"%u", value];
    }
}

static NSString *SFSysctlReadInt64(const char *name) {
    int64_t value;
    size_t size = sizeof(value);
    int err = sysctlbyname(name, &value, &size, NULL, 0);
    if (err) {
        SF_DEBUG(@"sysctlbyname(\"%s\", ...): %s", name, strerror(errno));
        return nil;
    } else {
        return [NSString stringWithFormat:@"%lld", value];
    }
}

- (NSDictionary *)createReport {
    NSMutableDictionary *report = [NSMutableDictionary new];

    UIDevice *device = [UIDevice currentDevice];
    for (NSString *propertyName in @[@"name", @"systemName", @"systemVersion", @"model", @"localizedModel"]) {
        SEL selector = NSSelectorFromString(propertyName);
        NSString *(*func)(id, SEL) = (void *)[device methodForSelector:selector];
        NSString *property = [NSString stringWithString:func(device, selector)];
        if (property) {
            [report setObject:property forKey:SFCamelCaseToSnakeCase(propertyName)];
        }
    }

    UIScreen *screen = [UIScreen mainScreen];
    NSInteger width = screen.fixedCoordinateSpace.bounds.size.width * screen.scale;
    NSInteger height = screen.fixedCoordinateSpace.bounds.size.height * screen.scale;
    [report setObject:[@(width) stringValue] forKey:@"screen_width"];
    [report setObject:[@(height) stringValue] forKey:@"screen_height"];

    ASIdentifierManager *identifierManager = [ASIdentifierManager sharedManager];
    [report setObject:[identifierManager.advertisingIdentifier UUIDString] forKey:@"apple_ifa"];
    [report setObject:[[device identifierForVendor] UUIDString] forKey:@"apple_ifv"];

    [report setObject:[self getPersistentUniqueId] forKey:@"device_id"];

    CTTelephonyNetworkInfo *networkInfo = [CTTelephonyNetworkInfo new];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    if (carrier) {
        for (NSString *propertyName in @[@"carrierName", @"isoCountryCode", @"mobileCountryCode", @"mobileNetworkCode"]) {
            SEL selector = NSSelectorFromString(propertyName);
            NSString *(*func)(id, SEL) = (void *)[carrier methodForSelector:selector];
            NSString *property = [NSString stringWithString:func(carrier, selector)];
            if (property) {
                [report setObject:property forKey:SFCamelCaseToSnakeCase(propertyName)];
            }
        }
    }

    struct {
        const char *name;
        NSString *(*read)(const char *);
    } sysctlProperties[] = {
        {"hw.machine", SFSysctlReadString},
        {"hw.model", SFSysctlReadString},
        {"kern.bootsessionuuid", SFSysctlReadString},
        {"kern.bootsignature", SFSysctlReadString},
        {"kern.hostname", SFSysctlReadString},
        {"kern.ostype", SFSysctlReadString},
        {"kern.osrelease", SFSysctlReadString},
        {"kern.uuid", SFSysctlReadString},
        {"kern.version", SFSysctlReadString},

        {"hw.ncpu", SFSysctlReadUInt32},
        {"hw.byteorder", SFSysctlReadUInt32},
        {"hw.activecpu", SFSysctlReadUInt32},
        {"hw.physicalcpu", SFSysctlReadUInt32},
        {"hw.physicalcpu_max", SFSysctlReadUInt32},
        {"hw.logicalcpu", SFSysctlReadUInt32},
        {"hw.logicalcpu_max", SFSysctlReadUInt32},
        {"hw.cputype", SFSysctlReadUInt32},
        {"hw.cpusubtype", SFSysctlReadUInt32},
        {"hw.cpu64bit_capable", SFSysctlReadUInt32},
        {"hw.cpufamily", SFSysctlReadUInt32},
        {"hw.packages", SFSysctlReadUInt32},
        {"hw.optional.floatingpoint", SFSysctlReadUInt32},
        {"kern.hostid", SFSysctlReadUInt32},
        {"kern.osrevision", SFSysctlReadUInt32},
        {"kern.posix1version", SFSysctlReadUInt32},
        {"user.posix2_version", SFSysctlReadUInt32},

        {"hw.busfrequency", SFSysctlReadInt64},
        {"hw.busfrequency_min", SFSysctlReadInt64},
        {"hw.busfrequency_max", SFSysctlReadInt64},
        {"hw.cachelinesize", SFSysctlReadInt64},
        {"hw.cpufrequency", SFSysctlReadInt64},
        {"hw.cpufrequency_max", SFSysctlReadInt64},
        {"hw.cpufrequency_min", SFSysctlReadInt64},
        {"hw.l1icachesize", SFSysctlReadInt64},
        {"hw.l1dcachesize", SFSysctlReadInt64},
        {"hw.l2cachesize", SFSysctlReadInt64},
        {"hw.l3cachesize", SFSysctlReadInt64},
        {"hw.memsize", SFSysctlReadInt64},
        {"hw.pagesize", SFSysctlReadInt64},
        {"hw.tbfrequency", SFSysctlReadInt64},
    };
    for (int i = 0; i < sizeof(sysctlProperties) / sizeof(sysctlProperties[0]); i++) {
        NSString *property = sysctlProperties[i].read(sysctlProperties[i].name);
        if (property) {
            NSString *key = [NSString stringWithCString:sysctlProperties[i].name encoding:NSASCIIStringEncoding];
            [report setObject:property forKey:key];
        }
    }

    SF_DEBUG(@"Device properties: %@", report);
    return report;
}

- (NSString *)getPersistentUniqueId {
    NSMutableDictionary *keychainItemBase = [NSMutableDictionary new];
    keychainItemBase[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    keychainItemBase[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAlways;
    keychainItemBase[(__bridge id)kSecAttrAccount] = @"device_id";
    keychainItemBase[(__bridge id)kSecAttrService] = @"siftscience.keychain";

    NSMutableDictionary *keychainItem;

    keychainItem = [NSMutableDictionary dictionaryWithDictionary:keychainItemBase];
    keychainItem[(__bridge id)kSecReturnAttributes] = (__bridge id)kCFBooleanTrue;
    keychainItem[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    CFDictionaryRef dict = nil;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainItem, (CFTypeRef *)&dict) == noErr) {
        NSDictionary *item = (__bridge_transfer NSDictionary *)dict;
        NSData *data = item[(__bridge id)kSecValueData];
        NSString *persistentUniqueId = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        SF_DEBUG(@"Return persistent unique ID: %@", persistentUniqueId);
        return persistentUniqueId;
    }

    NSString *randomUuid = [[NSUUID UUID] UUIDString];
    SF_DEBUG(@"Create new persistent unique ID: %@", randomUuid);

    keychainItem = [NSMutableDictionary dictionaryWithDictionary:keychainItemBase];
    keychainItem[(__bridge id)kSecValueData] = [randomUuid dataUsingEncoding:NSUTF8StringEncoding];
    SecItemAdd((__bridge CFDictionaryRef)keychainItem, NULL);

    return randomUuid;
}

- (void)report:(NSString *)userId {
    NSAssert(!SFEventIsEmptyUserId(userId), @"userId is empty");

    SFEvent *event = [SFEvent new];
    event.userId = userId;
    event.deviceProperties = [self createReport];
    [[Sift sharedInstance] appendEvent:event toQueue:SFDevicePropertiesReporterQueueIdentifier];
}

@end
