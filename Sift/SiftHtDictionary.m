// Copyright (c) 2016 Sift Science. All rights reserved.

#import "SiftCompatibility.h"
#import "SiftDebug.h"

#import "SiftHtDictionary.h"

@implementation SiftHtDictionary

- (instancetype)initWithEntryTypes:(SF_GENERICS(NSDictionary, NSString *, Class) *)entryTypes {
    self = [super init];
    if (self) {
        _entryTypes = entryTypes;
        _entries = [NSMutableDictionary new];
    }
    return self;
}

- (BOOL)isEqual:(id)object {
    if (self == object) {
        return YES;
    }
    if (![object isKindOfClass:SiftHtDictionary.class]) {
        return NO;
    }
    SiftHtDictionary *other = object;
    return [self.entries isEqualToDictionary:other.entries];
}

- (BOOL)setEntry:(NSString *)key value:(id)value {
    if (value == nil) {
        SF_DEBUG(@"Ignore `nil` value: %@", key);
        return NO;
    }
    Class entryType = [_entryTypes objectForKey:key];
    if (!entryType) {
        SF_DEBUG(@"Could not find entry key: %@", key);
        return NO;
    }
    if (![value isKindOfClass:entryType]) {
        SF_DEBUG(@"Entry %@ not %@-typed: %@", key, entryType, value);
        return NO;
    }
    if (entryType == [NSNumber class]) {
        if (isnan([value doubleValue])) {
            SF_DEBUG(@"Encountered NaN for key %@", key);
            return NO;
        }
        if (isinf([value doubleValue])) {
            SF_DEBUG(@"Encountered Infinity for key %@", key);
            return NO;
        }
    }
    [_entries setObject:value forKey:key];
    return YES;
}

#pragma mark - NSCoding

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _entries = [NSMutableDictionary new];
        [_entries addEntriesFromDictionary:[decoder decodeObjectForKey:@"entries"]];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
  [encoder encodeObject:self.entries forKey:(@"entries")];
}

@end
