// Copyright (c) 2016 Sift Science. All rights reserved.

@import AdSupport;
@import CoreTelephony;
@import Foundation;
@import UIKit;

#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <mach-o/dyld.h>

#import "SFDebug.h"
#import "SFQueueConfig.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFDevicePropertiesReporter.h"

/**
 * Device properties are sent to their own queue, which is configured to
 * record only difference (we assume that device properties are rarely
 * changed).
 */
static const SFQueueConfig SFDevicePropertiesReporterQueueConfig = {
    .appendEventOnlyWhenDifferent = YES,  // Only track difference.
    .acceptSameEventAfter = 600,  // 10 minutes
    .uploadWhenMoreThan = 8,  // More than 8 events
    .uploadWhenOlderThan = 60,  // 1 minute
};

static NSString * const SFDevicePropertiesReporterQueueIdentifier = @"sift-devprops";

static const int64_t SF_START = 0;  // Start immediately
static const int64_t SF_INTERVAL = 60 * NSEC_PER_SEC;  // Repeate every 1 minute
static const int64_t SF_LEEWAY = 5 * NSEC_PER_SEC;

@interface SFDevicePropertiesReporter ()

/** Report device properties through its own queue. */
- (void)report;

/** Collect ordinary system properties. */
- (void)collectProperties:(NSMutableDictionary<NSString *, NSString *> *)report;

/** @return a persistent, unique key of this device. */
- (NSString *)getPersistentUniqueKey;

/** Detect signs of a jail-broken device. */
- (void)collectSystemProperties:(NSMutableDictionary<NSString *, NSString *> *)report;

@end

@implementation SFDevicePropertiesReporter {
    dispatch_source_t _source;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        Sift *sift = [Sift sharedInstance];
        if (![sift addEventQueue:SFDevicePropertiesReporterQueueIdentifier config:SFDevicePropertiesReporterQueueConfig]) {
            SF_DEBUG(@"Could not create \"%@\" queue", SFDevicePropertiesReporterQueueIdentifier);
            self = nil;
            return nil;
        }

        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
        dispatch_source_set_timer(_source, dispatch_time(DISPATCH_TIME_NOW, SF_START), SF_INTERVAL, SF_LEEWAY);
        SFDevicePropertiesReporter * __weak weakSelf = self;
        dispatch_source_set_event_handler(_source, ^{[weakSelf report];});
        dispatch_resume(_source);
    }
    return self;
}

- (void)report {
    SF_DEBUG(@"Collect device properties...");

    Sift *sift = [Sift sharedInstance];

    NSString *userId = sift.userId;
    if (!userId.length) {
        SF_DEBUG(@"userId is empty");
        return;
    }

    NSMutableDictionary<NSString *, NSString *> *report = [NSMutableDictionary new];
    [self collectProperties:report];
    [self collectSystemProperties:report];
    if (!report.count) {
        SF_DEBUG(@"Nothing to report about");
        return;
    }

    SF_DEBUG(@"Device properties: %@", report);
    SFEvent *event = [SFEvent new];
    event.deviceProperties = report;
    [sift appendEvent:event withLocation:NO toQueue:SFDevicePropertiesReporterQueueIdentifier];
}

#pragma mark - Device properties.

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

- (void)collectProperties:(NSMutableDictionary<NSString *, NSString *> *)report {
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

    [report setObject:[self getPersistentUniqueKey] forKey:@"unique_key"];

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
}

#pragma mark - Unique key

- (NSString *)getPersistentUniqueKey {
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

#pragma mark - Jail-broken

// TODO(clchiou): Test this on a jailbroken device and see how many suspicious things we could find.

/**
 * Collect properties for detecting whether this device is jail broken.
 *
 * The detections implemented here are from public sources, meaning a
 * determined jail breaker should know and be able to patch around all
 * of them.
 *
 * NOTE: Don't leave "obvious" string constants or exposed symbol names
 * like "jail broken" in the compiled binary - this would make reverse
 * engineer's job slightly harder of finding the detection code with
 * simple full text search (and patching around it).
 */
- (void)collectSystemProperties:(NSMutableDictionary<NSString *, NSString *> *)report {

    // 1. Filesystem-based detection.

    // Files that are typical to a jail-broken device, which are ROT13
    // encoded to hide from simple full text search - it can't stop a
    // determined mind but could slow it down a bit.
    char paths[] = \
        "/cevingr/ine/fgnfu\n"
        "/cevingr/ine/yvo/ncg\n"
        "/cevingr/ine/gzc/plqvn.ybt\n"
        "/cevingr/ine/yvo/plqvn\n"
        "/cevingr/ine/zbovyr/Yvoenel/FOFrggvatf/Gurzrf\n"
        "/Yvoenel/ZbovyrFhofgengr/ZbovyrFhofgengr.qlyvo\n"
        "/Yvoenel/ZbovyrFhofgengr/QlanzvpYvoenevrf/Irrapl.cyvfg\n"
        "/Yvoenel/ZbovyrFhofgengr/QlanzvpYvoenevrf/YvirPybpx.cyvfg\n"
        "/Flfgrz/Yvoenel/YnhapuQnrzbaf/pbz.vxrl.oobg.cyvfg\n"
        "/Flfgrz/Yvoenel/YnhapuQnrzbaf/pbz.fnhevx.Plqvn.Fgneghc.cyvfg\n"
        "/ine/pnpur/ncg\n"
        "/ine/yvo/ncg\n"
        "/ine/yvo/plqvn\n"
        "/ine/ybt/flfybt\n"
        "/ine/gzc/plqvn.ybt\n"
        "/ova/onfu\n"
        "/ova/fu\n"
        "/hfe/fova/ffuq\n"
        "/hfe/yvorkrp/ffu-xrlfvta\n"
        "/hfe/fova/ffuq\n"
        "/hfe/ova/ffuq\n"
        "/hfe/yvorkrp/fsgc-freire\n"
        "/rgp/ffu/ffuq_pbasvt\n"
        "/rgp/ncg\n"
        "/Nccyvpngvbaf/Plqvn.ncc\n"
        "/Nccyvpngvbaf/EbpxNcc.ncc\n"
        "/Nccyvpngvbaf/Vpl.ncc\n"
        "/Nccyvpngvbaf/JvagreObneq.ncc\n"
        "/Nccyvpngvbaf/FOFrggvatf.ncc\n"
        "/Nccyvpngvbaf/ZkGhor.ncc\n"
        "/Nccyvpngvbaf/VagryyvFperra.ncc\n"
        "/Nccyvpngvbaf/SnxrPneevre.ncc\n"
        "/Nccyvpngvbaf/oynpxen1a.ncc\n"
        "/Nccyvpngvbaf/oynpxfa0j.ncc\n"
        "/Nccyvpngvbaf/terracbvf0a.ncc\n"
        "/Nccyvpngvbaf/yvzren1a.ncc\n"
        "/Nccyvpngvbaf/erqfa0j.ncc\n";
    rot13(paths);

    for (char i = 0, *cpath = paths, *end; (end = strchr(cpath, '\n')) != NULL; cpath = end + 1) {
        *end = '\0';
        if (!access(cpath, F_OK)) {
            SF_DEBUG(@"Found file: \"%s\"", cpath);
            NSString *path = [NSString stringWithCString:cpath encoding:NSASCIIStringEncoding];
            [report setObject:path forKey:[NSString stringWithFormat:@"suspicious_file.%d", i++]];
        }
    }

    // Dirs that should not be writable nor symlinks. (ROT-13 encoded)
    char dirs[] = \
        "/\n"
        "/Yvoenel/Evatgbarf\n"
        "/Yvoenel/Jnyycncre\n"
        "/cevingr\n"
        "/hfe/nez-nccyr-qnejva9\n"
        "/hfe/vapyhqr\n"
        "/hfe/yvorkrp\n"
        "/hfe/funer\n"
        "/Nccyvpngvbaf\n";
    rot13(dirs);

    for (char i = 0, j = 0, *cpath = dirs, *end; (end = strchr(cpath, '\n')) != NULL; cpath = end + 1) {
        *end = '\0';
        struct stat dirStat;
        if (!lstat(cpath, &dirStat)) {
            NSString *path = [NSString stringWithCString:cpath encoding:NSASCIIStringEncoding];
            if (S_ISLNK(dirStat.st_mode)) {
                SF_DEBUG(@"\"%@\" is a symlink", path);
                [report setObject:path forKey:[NSString stringWithFormat:@"suspicious_symlink.%d", i++]];
            }
            if (dirStat.st_mode & S_IWOTH) {
                SF_DEBUG(@"\"%@\" is writable by others", path);
                [report setObject:path forKey:[NSString stringWithFormat:@"suspicious_permission.%d", j++]];
            }
        }
    }

    // 2. Sytem-call detection.

    pid_t pid = fork();
    if (!pid) {
        exit(0);
    } else if (pid > 0) {
        SF_DEBUG(@"fork() does not return error");
        [report setObject:@"fork" forKey:@"suspicious_call.0"];
        waitpid(pid, NULL, 0);
    }

    // system(NULL) will trigger SIGABRT?

    // 3. Cydia URL scheme detection.

    char cscheme[] = "plqvn";
    rot13(cscheme);
    char curlpath[] = "://cnpxntr/pbz.rknzcyr.cnpxntr";
    rot13(curlpath);

    NSString *scheme = [NSString stringWithCString:cscheme encoding:NSASCIIStringEncoding];
    NSString *urlpath = [NSString stringWithCString:curlpath encoding:NSASCIIStringEncoding];
    NSString *url = [scheme stringByAppendingString:urlpath];
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]]) {
        SF_DEBUG(@"Can open URL: %@", url);
        [report setObject:scheme forKey:@"suspicious_url_scheme.0"];
    }

    // 4. dyld detection.

    char dyldname[] = "ZbovyrFhofgengr";  // "MobileSubstrate"
    rot13(dyldname);

    uint32_t count = _dyld_image_count();
    for (uint32_t index = 0, i = 0; i < count; i++) {
        const char *cdyld = _dyld_get_image_name(i);
        if (strstr(cdyld, dyldname)) {
            NSString *dyld = [NSString stringWithCString:cdyld encoding:NSASCIIStringEncoding];
            SF_DEBUG(@"Found dyld: \"%@\"", dyld);
            [report setObject:dyld forKey:[NSString stringWithFormat:@"suspicious_dyld.%d", (int)index++]];
        }
    }
}

static void rot13(char *p) {
    while (*p) {
        if (isalpha(*p)) {
            char alpha = islower(*p) ? 'a' : 'A';
            *p = (*p - alpha + 13) % 26 + alpha;
        }
        p++;
    }
}

@end
