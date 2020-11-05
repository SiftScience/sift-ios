// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftDebug.h"

#import "SiftIosDeviceProperties.h"

@interface SiftIosDevicePropertiesTests : XCTestCase

@end

@implementation SiftIosDevicePropertiesTests

- (void)testCollect {
    SiftHtDictionary *actual = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", actual.entries);
    XCTAssertNotNil(actual);
}

- (void)testCoder {
    SiftHtDictionary *expect, *actual;
    NSData *data;

    // Test empty object.
    expect = SFMakeEmptyIosDeviceProperties();
    XCTAssertEqual(0, expect.entries.count);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }

    XCTAssertEqual(0, actual.entries.count);
    XCTAssertEqualObjects(expect, actual);

    // Test object with a handful of properties.
    expect = SFMakeEmptyIosDeviceProperties();
    [expect setEntry:@"app_name" value:@"test-string"];
    [expect setEntry:@"app_version" value:@""];
    [expect setEntry:@"cpu_has_fp" value:[NSNumber numberWithBool:YES]];
    [expect setEntry:@"cache_line_size" value:[NSNumber numberWithLong:64]];
    [expect setEntry:@"evidence_files_present" value:@[@"a", @"b", @"c"]];
    [expect setEntry:@"evidence_directories_writable" value:@[]];
    XCTAssertEqual(6, expect.entries.count);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }

    XCTAssertEqual(6, actual.entries.count);
    XCTAssertEqualObjects(expect, actual);
}

- (void)testWithRandomData {
    SiftHtDictionary *z = SFMakeEmptyIosDeviceProperties();  // Empty object.
    SiftHtDictionary *p = [self generateRandomProperties];  // Random object 1.
    SiftHtDictionary *q = [self generateRandomProperties];  // Random object 2.

    XCTAssertNotEqualObjects(z, p);
    XCTAssertNotEqualObjects(z, q);
    XCTAssertNotEqualObjects(p, q);

    SiftHtDictionary *actual;
    NSData *data;

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:p requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:p];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    XCTAssertEqualObjects(p, actual);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:q requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:q];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    XCTAssertEqualObjects(q, actual);
}

- (void)testMacCatalyst {
    SiftHtDictionary *actual = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", actual.entries);
    XCTAssertNotNil(actual);
    
    NSString *deviceName = actual.entries[@"device_system_name"];
    #if !TARGET_OS_MACCATALYST
        XCTAssertFalse([deviceName containsString:@"Mac"]);
    #else
        XCTAssertTrue([deviceName containsString:@"Mac"]);
    #endif
}

- (SiftHtDictionary *)generateRandomProperties {
    SiftHtDictionary *properties = SFMakeEmptyIosDeviceProperties();
    for (NSString *name in properties.entryTypes) {
        Class entryType = [properties.entryTypes objectForKey:name];
        id value = nil;
        if (entryType == NSNumber.class) {
            value = [NSNumber numberWithLong:arc4random_uniform(1 << 20)];
        } else if (entryType == NSString.class) {
            value = [self generateRandomString];
        } else if (entryType == NSArray.class) {
            NSMutableArray *strings = [NSMutableArray new];
            int n = arc4random_uniform(128);
            while (n-- > 0) {
                [strings addObject:[self generateRandomString]];
            }
            value = strings;
        } else {
            XCTFail(@"Unsupported type");
        }
        [properties setEntry:name value:value];
    }
    return properties;
}

- (NSString *)generateRandomString {
    char buffer[128];
    int n = arc4random_uniform(sizeof(buffer));
    buffer[n--] = '\0';
    while (n >= 0) {
        buffer[n--] = 'a' + arc4random_uniform(26);
    }
    return [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
}

@end
