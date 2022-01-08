// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftDebug.h"

#import "SiftIosDeviceProperties.h"

@interface SiftIosDevicePropertiesTests : XCTestCase

@end

@implementation SiftIosDevicePropertiesTests

- (void)testCollect {
    NSDictionary *actual = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", actual);
    XCTAssertNotNil(actual);
}

- (void)testCoder {
    NSDictionary *expect, *actual;
    NSData *data;

    // Test empty object.
    expect = SFMakeEmptyIosDeviceProperties();
    XCTAssertEqual(0, expect.count);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }

    XCTAssertEqual(0, actual.count);
    XCTAssertEqualObjects(expect, actual);

    // Test object with a handful of properties.
    expect = SFMakeEmptyIosDeviceProperties();
    [expect setValue:@"test-string" forKey:@"app_name"];
    [expect setValue:@"" forKey:@"app_version"];
    [expect setValue:@[@"a", @"b", @"c"] forKey:@"evidence_files_present"];
    [expect setValue:@[] forKey:@"evidence_directories_writable"];
    XCTAssertEqual(4, expect.count);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }

    XCTAssertEqual(4, actual.count);
    XCTAssertEqualObjects(expect, actual);
}

- (void)testWithRandomData {
    NSDictionary *z = SFMakeEmptyIosDeviceProperties();  // Empty object.
    NSDictionary *p = [self generateRandomProperties];  // Random object 1.
    NSDictionary *q = [self generateRandomProperties];  // Random object 2.

    XCTAssertNotEqualObjects(z, p);
    XCTAssertNotEqualObjects(z, q);
    XCTAssertNotEqualObjects(p, q);

    NSDictionary *actual;
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
    NSDictionary *actual = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", actual);
    XCTAssertNotNil(actual);
    
    NSString *deviceName = actual[@"device_system_name"];
    #if !TARGET_OS_MACCATALYST
        XCTAssertFalse([deviceName containsString:@"Mac"]);
    #else
        XCTAssertTrue([deviceName containsString:@"Mac"]);
    #endif
}

- (NSDictionary *)generateRandomProperties {
    NSMutableDictionary *properties = SFMakeEmptyIosDeviceProperties();
    [properties setValue:[self generateRandomString] forKey:@"app_name"];
    [properties setValue:[self generateRandomString] forKey:@"app_version"];
    [properties setValue:[self generateRandomArray] forKey:@"evidence_files_present"];
    [properties setValue:[self generateRandomArray] forKey:@"evidence_directories_writable"];
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

- (NSArray *)generateRandomArray {
    NSMutableArray *strings = [NSMutableArray new];
    int n = arc4random_uniform(128);
    while (n-- > 0) {
        [strings addObject:[self generateRandomString]];
    }
    return strings;
}

@end
