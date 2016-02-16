// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFDevicePropertiesReporter.h"

@interface SFDevicePropertiesReporterTests : XCTestCase

@end

@implementation SFDevicePropertiesReporterTests

- (void)testCreateReport {
    NSDictionary *report = [[SFDevicePropertiesReporter new] createReport];
    XCTAssertNotNil(report);
    XCTAssert(report.count > 0);
    for (id key in [report allKeys]) {
        XCTAssert([key isKindOfClass:[NSString class]]);
        XCTAssert([[report objectForKey:key] isKindOfClass:[NSString class]]);
    }
}

- (void)testJailBroken {
    NSMutableDictionary *report = [NSMutableDictionary new];
    [[SFDevicePropertiesReporter new] collectSystemProperties:report];
    // A simulator should trigger a few suspicious signs.
    XCTAssertGreaterThan(report.count, 0);
}

@end
