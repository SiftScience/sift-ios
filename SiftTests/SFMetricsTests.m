// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFMetrics.h"

#define ARRAY_SIZE(array) (sizeof(array) / sizeof((array)[0]))

@interface SFMetricsTests : XCTestCase

@end

@implementation SFMetricsTests

- (void)testMetrics {
    SFMetrics *metrics = [SFMetrics new];

#define SF_METRICS_MAKE(name) SFMetricsKey ## name
    static const SFMetricsKey counterKeys[] = {
        SF_METRICS_COUNTERS(SF_COMMA)
    };
    static const SFMetricsKey meterKeys[] = {
        SF_METRICS_METERS(SF_COMMA)
    };
#undef SF_METRICS_MAKE

    for (int numRuns = 0; numRuns < 3; numRuns++) {
        for (int i = 0; i < ARRAY_SIZE(counterKeys); i++) {
            [metrics count:counterKeys[i] value:(numRuns + i)];
        }

        for (int i = 0; i < ARRAY_SIZE(meterKeys); i++) {
            [metrics measure:meterKeys[i] value:1.0];
            [metrics measure:meterKeys[i] value:2.0];
            [metrics measure:meterKeys[i] value:3.0];
        }

        [metrics enumerateCountersUsingBlock:^(SFMetricsKey key, NSInteger count) {
            for (int i = 0; i < ARRAY_SIZE(counterKeys); i++) {
                if (counterKeys[i] == key) {
                    XCTAssertEqual(numRuns + i, count);
                    return;
                }
            }
            XCTAssert(NO, @"Unreachable");
        }];

        [metrics enumerateMetersUsingBlock:^(SFMetricsKey key, const SFMetricsMeter *meter) {
            for (int i = 0; i < ARRAY_SIZE(meterKeys); i++) {
                if (meterKeys[i] == key) {
                    XCTAssertEqual(6.0, meter->sum);
                    XCTAssertEqual(14.0, meter->sumsq);
                    XCTAssertEqual(3, meter->count);
                    return;
                }
            }
            XCTAssert(NO, @"Unreachable");
        }];

        [metrics reset];
    }
}

@end
