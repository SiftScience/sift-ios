// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFUtils.h"

#import "SFEvent.h"

@implementation SFEvent

+ (SFEvent *)eventWithType:(NSString *)type path:(NSString *)path fields:(NSDictionary *)fields {
    SFEvent *event = [SFEvent new];
    if (type) {
        event.type = type;
    }
    if (path) {
        event.path = path;
    }
    if (fields) {
        event.fields = fields;
    }
    return event;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _time = SFCurrentTime();
        _type = nil;
        _path = nil;
        _userId = nil;
        _fields = nil;
        _deviceProperties = nil;
        _metrics = nil;
    }
    return self;
}

- (BOOL)isEssentiallyEqualTo:(SFEvent *)event {
    return event &&
           ((!_type && !event.type) || [_type isEqualToString:event.type]) &&
           ((!_path && !event.path) || [_path isEqualToString:event.path]) &&
           ((!_userId && !event.userId) || [_userId isEqualToString:event.userId]) &&
           ((!_fields && !event.fields) || [_fields isEqualToDictionary:event.fields]) &&
           ((!_deviceProperties && !event.deviceProperties) || [_deviceProperties isEqualToDictionary:event.deviceProperties]) &&
           ((!_metrics && !event.metrics) || [_metrics isEqualToDictionary:event.metrics]);
}

#pragma mark - NSCoding

// Keys for NSCoder.
static NSString * const SF_TIME = @"time";
static NSString * const SF_TYPE = @"type";
static NSString * const SF_PATH = @"path";
static NSString * const SF_USER_ID = @"userId";
static NSString * const SF_FIELDS = @"fields";
static NSString * const SF_DEVICE_PROPERTIES = @"deviceProperties";
static NSString * const SF_METRICS = @"metrics";

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _time = [decoder decodeInt64ForKey:SF_TIME];  // NSCoder doesn't support uint64_t :(
        _type = [decoder decodeObjectForKey:SF_TYPE];
        _path = [decoder decodeObjectForKey:SF_PATH];
        _userId = [decoder decodeObjectForKey:SF_USER_ID];
        _fields = [decoder decodeObjectForKey:SF_FIELDS];
        _deviceProperties = [decoder decodeObjectForKey:SF_DEVICE_PROPERTIES];
        _metrics = [decoder decodeObjectForKey:SF_METRICS];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    [encoder encodeInt64:_time forKey:SF_TIME];  // NSCoder doesn't support uint64_t :(
    [encoder encodeObject:_type forKey:SF_TYPE];
    [encoder encodeObject:_path forKey:SF_PATH];
    [encoder encodeObject:_userId forKey:SF_USER_ID];
    [encoder encodeObject:_fields forKey:SF_FIELDS];
    [encoder encodeObject:_deviceProperties forKey:SF_DEVICE_PROPERTIES];
    [encoder encodeObject:_metrics forKey:SF_METRICS];
}

@end
