// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFMetrics.h"
#import "SFMetricsReporter.h"

#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

@interface SFMetricsReporterTests : XCTestCase

@end

@implementation SFMetricsReporterTests

- (void)testCreateReport {
    SFMetrics *metrics = [SFMetrics new];

#define SF_METRICS_MAKE(name) SFMetricsKey ## name
    static const SFMetricsKey counterKeys[] = {
        SF_METRICS_COUNTERS(SF_COMMA)
    };
    static const SFMetricsKey meterKeys[] = {
        SF_METRICS_METERS(SF_COMMA)
    };
#undef SF_METRICS_MAKE

    for (int i = 0; i < ARRAY_SIZE(counterKeys); i++) {
        [metrics count:counterKeys[i]];
    }
    for (int i = 0; i < ARRAY_SIZE(meterKeys); i++) {
        [metrics measure:meterKeys[i] value:(i + 10)];
    }

    NSDictionary *report = [[SFMetricsReporter new] createReport:metrics startDate:[NSDate date] duration:1];
    XCTAssertNotNil(report);
    XCTAssert(report.count == 2 + ARRAY_SIZE(counterKeys) + ARRAY_SIZE(meterKeys) * 3);
    for (id key in [report allKeys]) {
        XCTAssert([key isKindOfClass:[NSString class]]);
        XCTAssert([[report objectForKey:key] isKindOfClass:[NSNumber class]]);
    }
}

@end
