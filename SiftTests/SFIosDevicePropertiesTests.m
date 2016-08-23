// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFIosDeviceProperties.h"

@interface SFIosDevicePropertiesTests : XCTestCase

@end

@implementation SFIosDevicePropertiesTests

- (void)testCoder {
    SFIosDeviceProperties *expect, *actual;
    NSData *data;

    // Test empty object.
    expect = [SFIosDeviceProperties new];
    XCTAssertEqual(0, expect.properties.count);

    data = [NSKeyedArchiver archivedDataWithRootObject:expect];
    actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertEqual(0, actual.properties.count);
    XCTAssertEqualObjects(expect, actual);

    // Test object with a handful of properties.
    expect = [SFIosDeviceProperties new];
    [expect setProperty:@"app_name" value:@"test-string"];
    [expect setProperty:@"app_version" value:@""];
    [expect setProperty:@"cpu_has_fp" value:[NSNumber numberWithBool:YES]];
    [expect setProperty:@"cache_line_size" value:[NSNumber numberWithLong:64]];
    [expect setProperty:@"evidence_files_present" value:@[@"a", @"b", @"c"]];
    [expect setProperty:@"evidence_directories_writable" value:@[]];
    XCTAssertEqual(6, expect.properties.count);

    data = [NSKeyedArchiver archivedDataWithRootObject:expect];
    actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertEqual(6, actual.properties.count);
    XCTAssertEqualObjects(expect, actual);

    // TODO(clchiou): Figure out a way to test calling setProperty with
    // invalid name and/or property value; need to mock out NSAssert?
}

- (void)testWithRandomData {
    SFIosDeviceProperties *z = [SFIosDeviceProperties new];  // Empty object.
    SFIosDeviceProperties *p = [self generateRandomProperties];  // Random object 1.
    SFIosDeviceProperties *q = [self generateRandomProperties];  // Random object 2.

    XCTAssertNotEqualObjects(z, p);
    XCTAssertNotEqualObjects(z, q);
    XCTAssertNotEqualObjects(p, q);

    SFIosDeviceProperties *actual;
    NSData *data;

    data = [NSKeyedArchiver archivedDataWithRootObject:p];
    actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    XCTAssertEqualObjects(p, actual);

    data = [NSKeyedArchiver archivedDataWithRootObject:q];
    actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    XCTAssertEqualObjects(q, actual);
}

- (SFIosDeviceProperties *)generateRandomProperties {
    SFIosDeviceProperties *properties = [SFIosDeviceProperties new];
    for (NSString *name in SFIosDevicePropertySpec.specs) {
        SFIosDevicePropertySpec *spec = [SFIosDevicePropertySpec.specs objectForKey:name];
        id value = nil;
        switch (spec.type) {
            case SFIosDevicePropertyTypeBool:
                value = [NSNumber numberWithBool:arc4random_uniform(1)];
                break;
            case SFIosDevicePropertyTypeInteger:
                value = [NSNumber numberWithLong:arc4random_uniform(1 << 20)];
                break;
            case SFIosDevicePropertyTypeDouble:
                value = [NSNumber numberWithDouble:drand48()];
                break;
            case SFIosDevicePropertyTypeString:
                value = [self generateRandomString];
                break;
            case SFIosDevicePropertyTypeStringArray:
                {
                    NSMutableArray *strings = [NSMutableArray new];
                    int n = arc4random_uniform(128);
                    while (n-- > 0) {
                        [strings addObject:[self generateRandomString]];
                    }
                    value = strings;
                    break;
                }
            default:
                XCTFail(@"Unknown type");
        }
        [properties setProperty:name value:value];
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
