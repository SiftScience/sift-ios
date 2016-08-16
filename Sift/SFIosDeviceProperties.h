// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

typedef NS_ENUM(NSInteger, SFIosDevicePropertyType) {
    SFIosDevicePropertyTypeBool,
    SFIosDevicePropertyTypeInteger,
    SFIosDevicePropertyTypeDouble,
    SFIosDevicePropertyTypeString,
    SFIosDevicePropertyTypeStringArray
};

typedef NS_ENUM(NSInteger, SFIosDevicePropertySysctlType) {
    SFIosDevicePropertySysctlTypeNone,
    SFIosDevicePropertySysctlTypeInt32,
    SFIosDevicePropertySysctlTypeInt64,
    SFIosDevicePropertySysctlTypeString,
};

@interface SFIosDevicePropertySpec : NSObject

+ (NSDictionary<NSString *, SFIosDevicePropertySpec *> *)specs;

@property (readonly) NSString *name;
@property (readonly) SFIosDevicePropertyType type;

@property (readonly) NSString *sysctlName;
@property (readonly) SFIosDevicePropertySysctlType sysctlType;

@end

@interface SFIosDeviceProperties : NSObject <NSCoding>

@property NSMutableDictionary *properties;

- (void)setProperty:(NSString *)name value:(id)value;

@end
