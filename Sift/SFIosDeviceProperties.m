// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFUtils.h"

#import "SFIosDeviceProperties.h"

@implementation SFIosDevicePropertySpec

+ (NSDictionary<NSString *, SFIosDevicePropertySpec *> *)specs {
    static NSMutableDictionary<NSString *, SFIosDevicePropertySpec *> *specs;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        specs = [NSMutableDictionary new];
#define ADD_PROP(name_, type_, sysctlName_, sysctlType_) [specs setObject:[[SFIosDevicePropertySpec alloc] initWithName:name_ type:type_ sysctlName:sysctlName_ sysctlType:sysctlType_] forKey:name_]

        ADD_PROP(@"app_name",          SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"app_version",       SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"app_version_short", SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"device_name", SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"device_ifv", SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"device_screen_width",  SFIosDevicePropertyTypeInteger, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"device_screen_height", SFIosDevicePropertyTypeInteger, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"device_model",           SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"device_localized_model", SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"device_system_name",     SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"device_system_version",  SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"device_hardware_machine", SFIosDevicePropertyTypeString, @"hw.machine", SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_hardware_model", SFIosDevicePropertyTypeString, @"hw.model", SFIosDevicePropertySysctlTypeString);

        ADD_PROP(@"device_package_count", SFIosDevicePropertyTypeInteger, @"hw.packages", SFIosDevicePropertySysctlTypeInt32);

        ADD_PROP(@"device_memory_size",  SFIosDevicePropertyTypeInteger, @"hw.memsize",     SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"device_page_size",    SFIosDevicePropertyTypeInteger, @"hw.pagesize",    SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"device_tb_frequency", SFIosDevicePropertyTypeInteger, @"hw.tbfrequency", SFIosDevicePropertySysctlTypeInt64);

        ADD_PROP(@"device_kernel_uuid",              SFIosDevicePropertyTypeString, @"kern.uuid",            SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_kernel_version",           SFIosDevicePropertyTypeString, @"kern.version",         SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_kernel_boot_session_uuid", SFIosDevicePropertyTypeString, @"kern.bootsessionuuid", SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_kernel_boot_signature",    SFIosDevicePropertyTypeString, @"kern.bootsignature",   SFIosDevicePropertySysctlTypeString);

        ADD_PROP(@"device_host_id",   SFIosDevicePropertyTypeInteger, @"kern.hostid",   SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"device_host_name", SFIosDevicePropertyTypeString,  @"kern.hostname", SFIosDevicePropertySysctlTypeString);

        ADD_PROP(@"device_os_type",        SFIosDevicePropertyTypeString, @"kern.ostype",         SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_os_release",     SFIosDevicePropertyTypeString, @"kern.osrelease",      SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_os_revision",    SFIosDevicePropertyTypeString, @"kern.osrevision",     SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_posix1_version", SFIosDevicePropertyTypeString, @"kern.posix1version",  SFIosDevicePropertySysctlTypeString);
        ADD_PROP(@"device_posix2_version", SFIosDevicePropertyTypeString, @"user.posix2_version", SFIosDevicePropertySysctlTypeString);

        ADD_PROP(@"mobile_carrier_name",     SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"mobile_iso_country_code", SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"mobile_country_code",     SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"mobile_network_code",     SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"network_addresses", SFIosDevicePropertyTypeStringArray, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"cpu_family",     SFIosDevicePropertyTypeInteger, @"hw.cpufamily",  SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_type",       SFIosDevicePropertyTypeInteger, @"hw.cputype",    SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_subtype",    SFIosDevicePropertyTypeInteger, @"hw.cpusubtype", SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_byte_order", SFIosDevicePropertyTypeString,  @"hw.byteorder",  SFIosDevicePropertySysctlTypeInt32);

        ADD_PROP(@"cpu_64bit_capable", SFIosDevicePropertyTypeBool, @"hw.cpu64bit_capable",       SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_has_fp",        SFIosDevicePropertyTypeBool, @"hw.optional.floatingpoint", SFIosDevicePropertySysctlTypeInt32);

        ADD_PROP(@"cpu_count",              SFIosDevicePropertyTypeInteger, @"hw.ncpu",            SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_physical_cpu_count", SFIosDevicePropertyTypeInteger, @"hw.physicalcpu",     SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_physical_cpu_max",   SFIosDevicePropertyTypeInteger, @"hw.physicalcpu_max", SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_logical_cpu_count",  SFIosDevicePropertyTypeInteger, @"hw.logicalcpu",      SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_logical_cpu_max",    SFIosDevicePropertyTypeInteger, @"hw.logicalcpu_max",  SFIosDevicePropertySysctlTypeInt32);
        ADD_PROP(@"cpu_active_cpu_count",   SFIosDevicePropertyTypeInteger, @"hw.activecpu",       SFIosDevicePropertySysctlTypeInt32);

        ADD_PROP(@"cpu_frequency",     SFIosDevicePropertyTypeInteger, @"hw.cpufrequency",     SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"cpu_frequency_min",  SFIosDevicePropertyTypeInteger, @"hw.cpufrequency_min", SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"cpu_frequency_max", SFIosDevicePropertyTypeInteger, @"hw.cpufrequency_max", SFIosDevicePropertySysctlTypeInt64);

        ADD_PROP(@"cache_line_size",      SFIosDevicePropertyTypeInteger, @"hw.cachelinesize", SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"cache_l1_dcache_size", SFIosDevicePropertyTypeInteger, @"hw.l1dcachesize",  SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"cache_l1_icache_size", SFIosDevicePropertyTypeInteger, @"hw.l1icachesize",  SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"cache_l2_cache_size",  SFIosDevicePropertyTypeInteger, @"hw.l2cachesize",   SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"cache_l3_cache_size",  SFIosDevicePropertyTypeInteger, @"hw.l3cachesize",   SFIosDevicePropertySysctlTypeInt64);

        ADD_PROP(@"bus_frequency",     SFIosDevicePropertyTypeInteger, @"hw.busfrequency",     SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"bus_frequency_min", SFIosDevicePropertyTypeInteger, @"hw.busfrequency_min", SFIosDevicePropertySysctlTypeInt64);
        ADD_PROP(@"bus_frequency_max", SFIosDevicePropertyTypeInteger, @"hw.busfrequency_max", SFIosDevicePropertySysctlTypeInt64);

        ADD_PROP(@"evidence_files_present", SFIosDevicePropertyTypeStringArray, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"evidence_directories_writable",  SFIosDevicePropertyTypeStringArray, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"evidence_directories_symlinked", SFIosDevicePropertyTypeStringArray, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"evidence_syscalls_succeeded", SFIosDevicePropertyTypeStringArray, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"evidence_url_schemes_openable", SFIosDevicePropertyTypeStringArray, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"evidence_dylds_present", SFIosDevicePropertyTypeStringArray, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"battery_level", SFIosDevicePropertyTypeDouble, nil, SFIosDevicePropertySysctlTypeNone);
        ADD_PROP(@"battery_state", SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"device_orientation", SFIosDevicePropertyTypeString, nil, SFIosDevicePropertySysctlTypeNone);

        ADD_PROP(@"proximity_state", SFIosDevicePropertyTypeBool, nil, SFIosDevicePropertySysctlTypeNone);

#undef ADD_PROP
    });
    return specs;
}

- (instancetype)initWithName:(NSString *)name type:(SFIosDevicePropertyType)type sysctlName:(NSString *)sysctlName sysctlType:(SFIosDevicePropertySysctlType)sysctlType {
    self = [super init];
    if (self) {
        _name = name;
        _type = type;
        _sysctlName = sysctlName;
        _sysctlType = sysctlType;
    }
    return self;
}

@end

@implementation SFIosDeviceProperties

- (instancetype)init {
    self = [super init];
    if (self) {
        _properties = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }

    if (![object isKindOfClass:SFIosDeviceProperties.class]) {
        return NO;
    }

    SFIosDeviceProperties *other = object;
    for (NSString *name in SFIosDevicePropertySpec.specs) {
        SFIosDevicePropertySpec *spec = [SFIosDevicePropertySpec.specs objectForKey:name];
        id this = [self.properties objectForKey:spec.name];
        id that = [other.properties objectForKey:spec.name];
        if ((this == nil) != (that == nil)) {
            return NO;
        }
        if (this == nil) {
            continue;
        }
        switch (spec.type) {
            case SFIosDevicePropertyTypeBool:  // Fall through.
            case SFIosDevicePropertyTypeInteger:  // Fall through.
            case SFIosDevicePropertyTypeDouble:
                if (![this isEqualToNumber:that]) {
                    return NO;
                }
                break;
            case SFIosDevicePropertyTypeString:
                if (![this isEqualToString:that]) {
                    return NO;
                }
                break;
            case SFIosDevicePropertyTypeStringArray:
                if (![this isEqualToArray:that]) {
                    return NO;
                }
                break;
            default:
                SFFail();  // Unknown type.
        }
    }

    return YES;
}

- (void)setProperty:(NSString *)name value:(id)value {
    SFIosDevicePropertySpec *spec = [SFIosDevicePropertySpec.specs objectForKey:name];
    NSAssert(spec != nil, @"Could not find property name: %@", name);
    if (value == nil) {
        return;
    }
    switch (spec.type) {
        case SFIosDevicePropertyTypeBool:  // Fall through.
        case SFIosDevicePropertyTypeInteger:  // Fall through.
        case SFIosDevicePropertyTypeDouble:
            NSAssert([value isKindOfClass:NSNumber.class], @"Property %@ not NSNumber: %@", name, value);
            break;
        case SFIosDevicePropertyTypeString:
            NSAssert([value isKindOfClass:NSString.class], @"Property %@ not NSString: %@", name, value);
            break;
        case SFIosDevicePropertyTypeStringArray:
            NSAssert([value isKindOfClass:NSArray.class], @"Property %@ not NSArray: %@", name, value);
            break;
        default:
            SFFail();  // Unknown type.
    }
    [_properties setObject:value forKey:name];
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _properties = [NSMutableDictionary new];
        [_properties addEntriesFromDictionary:[decoder decodeObjectForKey:@"properties"]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
  [encoder encodeObject:self.properties forKey:(@"properties")];
}

@end
