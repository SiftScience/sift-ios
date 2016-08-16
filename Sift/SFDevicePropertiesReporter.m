// Copyright (c) 2016 Sift Science. All rights reserved.

@import AdSupport;
@import CoreTelephony;
@import Foundation;
@import UIKit;

#include <ctype.h>
#include <stdlib.h>
#include <string.h>

#include <arpa/inet.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <sys/types.h>
#include <sys/sysctl.h>
#include <sys/stat.h>
#include <unistd.h>

#include <mach-o/dyld.h>

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"
#import "SFIosDeviceProperties.h"
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
- (void)collectProperties:(SFIosDeviceProperties *)iosDeviceProperties;

/** Return device's IP addresses. */
- (NSArray<NSString *> *)getIpAddresses;

/** Detect signs of a jail-broken device. */
- (void)collectSystemProperties:(SFIosDeviceProperties *)iosDeviceProperties;

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

    SFIosDeviceProperties *iosDeviceProperties = [SFIosDeviceProperties new];
    [self collectProperties:iosDeviceProperties];
    [self collectSystemProperties:iosDeviceProperties];

    SF_DEBUG(@"Device properties: %@", iosDeviceProperties.properties);
    SFEvent *event = [SFEvent new];
    event.iosDeviceProperties = iosDeviceProperties;
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

static BOOL SFSysctlReadInt32(const char *name, int32_t *output) {
    size_t size = sizeof(*output);
    int err = sysctlbyname(name, output, &size, NULL, 0);
    if (err) {
        SF_DEBUG(@"sysctlbyname(\"%s\", ...): %s", name, strerror(errno));
        return NO;
    } else {
        return YES;
    }
}

static BOOL SFSysctlReadInt64(const char *name, int64_t *output) {
    size_t size = sizeof(*output);
    int err = sysctlbyname(name, output, &size, NULL, 0);
    if (err) {
        SF_DEBUG(@"sysctlbyname(\"%s\", ...): %s", name, strerror(errno));
        return NO;
    } else {
        return YES;
    }
}

- (void)collectProperties:(SFIosDeviceProperties *)iosDeviceProperties {

    NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
    [iosDeviceProperties setProperty:@"app_name" value:[infoDictionary objectForKey:(NSString *)kCFBundleNameKey]];
    [iosDeviceProperties setProperty:@"app_version" value:[infoDictionary objectForKey:(NSString *)kCFBundleVersionKey]];
    [iosDeviceProperties setProperty:@"app_version_short" value:[infoDictionary objectForKey:@"CFBundleShortVersionString"]];

    UIDevice *device = [UIDevice currentDevice];
    [iosDeviceProperties setProperty:@"device_name" value:device.name];
    [iosDeviceProperties setProperty:@"device_ifv" value:device.identifierForVendor.UUIDString];
    [iosDeviceProperties setProperty:@"device_model" value:device.model];
    [iosDeviceProperties setProperty:@"device_localized_model" value:device.localizedModel];
    [iosDeviceProperties setProperty:@"device_system_name" value:device.systemName];
    [iosDeviceProperties setProperty:@"device_system_version" value:device.systemVersion];

    UIScreen *screen = [UIScreen mainScreen];
    [iosDeviceProperties setProperty:@"device_screen_width" value:[NSNumber numberWithInt:(screen.fixedCoordinateSpace.bounds.size.width * screen.scale)]];
    [iosDeviceProperties setProperty:@"device_screen_height" value:[NSNumber numberWithInt:(screen.fixedCoordinateSpace.bounds.size.height * screen.scale)]];

    CTTelephonyNetworkInfo *networkInfo = [CTTelephonyNetworkInfo new];
    CTCarrier *carrier = [networkInfo subscriberCellularProvider];
    if (carrier) {
        [iosDeviceProperties setProperty:@"mobile_carrier_name" value:carrier.carrierName];
        [iosDeviceProperties setProperty:@"mobile_iso_country_code" value:carrier.isoCountryCode];
        [iosDeviceProperties setProperty:@"mobile_country_code" value:carrier.mobileCountryCode];
        [iosDeviceProperties setProperty:@"mobile_network_code" value:carrier.mobileNetworkCode];
    }

    [iosDeviceProperties setProperty:@"network_addresses" value:[self getIpAddresses]];

    for (NSString *name in SFIosDevicePropertySpec.specs) {
        SFIosDevicePropertySpec *spec = [SFIosDevicePropertySpec.specs objectForKey:name];
        if (!spec.sysctlName) {
            continue;
        }

        id value = nil;
        switch (spec.sysctlType) {
            case SFIosDevicePropertySysctlTypeInt32:
                {
                    int32_t buffer;
                    if (SFSysctlReadInt32(spec.sysctlName.UTF8String, &buffer)) {
                        switch (spec.type) {
                            case SFIosDevicePropertyTypeBool:
                                value = [NSNumber numberWithBool:buffer];
                                break;
                            case SFIosDevicePropertyTypeInteger:
                                value = [NSNumber numberWithLong:buffer];
                                break;
                            case SFIosDevicePropertyTypeString:
                                value = [NSString stringWithFormat:@"%ld", (long)buffer];
                                break;
                            default:
                                SFFail();  // Unknown type.
                        }
                    }
                    break;
                }
            case SFIosDevicePropertySysctlTypeInt64:
                {
                    int64_t buffer;
                    if (SFSysctlReadInt64(spec.sysctlName.UTF8String, &buffer)) {
                        value = [NSNumber numberWithLongLong:buffer];
                    }
                    break;
                }
            case SFIosDevicePropertySysctlTypeString:
                value = SFSysctlReadString(spec.sysctlName.UTF8String);
                break;
            default:
                SFFail();  // Unknown type.
        }

        if (value) {
            [iosDeviceProperties setProperty:name value:value];
        }
    }
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
- (void)collectSystemProperties:(SFIosDeviceProperties *)iosDeviceProperties {

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

    NSMutableArray<NSString *> *filesPresent = [NSMutableArray new];
    for (char *cpath = paths, *end; (end = strchr(cpath, '\n')) != NULL; cpath = end + 1) {
        *end = '\0';
        if (!access(cpath, F_OK)) {
            SF_DEBUG(@"Found file: \"%s\"", cpath);
            NSString *path = [NSString stringWithCString:cpath encoding:NSASCIIStringEncoding];
            [filesPresent addObject:path];
        }
    }
    [iosDeviceProperties setProperty:@"evidence_files_present" value:filesPresent];

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

    NSMutableArray<NSString *> *dirsSymlinked = [NSMutableArray new];
    NSMutableArray<NSString *> *dirsWritable = [NSMutableArray new];
    for (char *cpath = dirs, *end; (end = strchr(cpath, '\n')) != NULL; cpath = end + 1) {
        *end = '\0';
        struct stat dirStat;
        if (!lstat(cpath, &dirStat)) {
            NSString *path = [NSString stringWithCString:cpath encoding:NSASCIIStringEncoding];
            if (S_ISLNK(dirStat.st_mode)) {
                SF_DEBUG(@"\"%@\" is a symlink", path);
                [dirsSymlinked addObject:path];
            }
            if (dirStat.st_mode & S_IWOTH) {
                SF_DEBUG(@"\"%@\" is writable by others", path);
                [dirsWritable addObject:path];
            }
        }
    }
    [iosDeviceProperties setProperty:@"evidence_directories_symlinked" value:dirsSymlinked];
    [iosDeviceProperties setProperty:@"evidence_directories_writable" value:dirsWritable];

    // 2. Sytem-call detection.

    NSMutableArray<NSString *> *syscallsSucceeded = [NSMutableArray new];

    // This is not fork-safe; disable it until we figure out how to do
    // it safely.
#if 0
    pid_t pid = fork();
    if (!pid) {
        exit(0);
    } else if (pid > 0) {
        SF_DEBUG(@"fork() does not return error");
        waitpid(pid, NULL, 0);
        [syscallsSucceeded addObject:@"fork"];
    }
#endif

    // system(NULL) will trigger SIGABRT?

    [iosDeviceProperties setProperty:@"evidence_syscalls_succeeded" value:syscallsSucceeded];

    // 3. Cydia URL scheme detection.
    // Because when we poke iOS about this, it reports an error, and
    // that sometimes confuses SDK users, we will only poke once per
    // process.

    NSMutableArray<NSString *> *urlSchemesOpenable = [NSMutableArray new];

    // iOS 9 requires white-listing URL schemes; until we figure how to
    // detect this unobtrusively, disable this detection for now.
#if 0
    static BOOL hasTestedCscheme = NO;
    static BOOL cschemeTestResult = NO;

    char cscheme[] = "plqvn";
    rot13(cscheme);
    char curlpath[] = "://cnpxntr/pbz.rknzcyr.cnpxntr";
    rot13(curlpath);

    NSString *scheme = [NSString stringWithCString:cscheme encoding:NSASCIIStringEncoding];
    NSString *urlpath = [NSString stringWithCString:curlpath encoding:NSASCIIStringEncoding];
    NSString *url = [scheme stringByAppendingString:urlpath];
    if (!hasTestedCscheme) {
        cschemeTestResult = [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]];
        hasTestedCscheme = YES;
    }
    if (cschemeTestResult) {
        SF_DEBUG(@"Can open URL: %@", url);
        [urlSchemesOpenable addObject:scheme];
    }
#endif

    [iosDeviceProperties setProperty:@"evidence_url_schemes_openable" value:urlSchemesOpenable];

    // 4. dyld detection.

    NSMutableArray<NSString *> *dyldsPresent = [NSMutableArray new];

    char dyldname[] = "ZbovyrFhofgengr";  // "MobileSubstrate"
    rot13(dyldname);

    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *cdyld = _dyld_get_image_name(i);
        if (strstr(cdyld, dyldname)) {
            NSString *dyld = [NSString stringWithCString:cdyld encoding:NSASCIIStringEncoding];
            SF_DEBUG(@"Found dyld: \"%@\"", dyld);
            [dyldsPresent addObject:dyld];
        }
    }

    [iosDeviceProperties setProperty:@"evidence_dylds_present" value:dyldsPresent];
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

- (NSArray<NSString *> *)getIpAddresses {
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

@end
