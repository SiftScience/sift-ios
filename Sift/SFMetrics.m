// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#include <string.h>

#import "SFDebug.h"

#import "SFMetrics.h"

static NSString * const SFMetricsMetricNames[SFMetricsNumMetrics] = {
#define SF_METRICS_MAKE(name) [SFMetricsKey ## name] = @#name
    SF_METRICS_COUNTERS(SF_COMMA),
    SF_METRICS_METERS(SF_COMMA),
#undef SF_METRICS_MAKE
};

#define SF_METRICS_MAKE(name) SFMetricsKey ## name
static const SFMetricsKey SFMetricsFirstCounterKey = SF_METRICS_COUNTERS(+ 0 *);
static const SFMetricsKey SFMetricsLastCounterKey = SF_METRICS_COUNTERS(* 0 +);
static const SFMetricsKey SFMetricsFirstMeterKey = SF_METRICS_METERS(+ 0 *);
static const SFMetricsKey SFMetricsLastMeterKey = SF_METRICS_METERS(* 0 +);
#undef SF_METRICS_MAKE

#define SF_METRICS_MAKE(name) 1
static const NSInteger SFMetricsNumCounters = SF_METRICS_COUNTERS(+);
static const NSInteger SFMetricsNumMeters = SF_METRICS_METERS(+);
#undef SF_METRICS_MAKE

NSString *SFMetricsMetricName(SFMetricsKey key) {
    return (key < 0 || key >= SFMetricsNumMetrics) ? nil : SFMetricsMetricNames[key];
}

@implementation SFMetrics {
    NSInteger _counters[SFMetricsNumCounters];
    SFMetricsMeter _meters[SFMetricsNumMeters];
}

+ (instancetype)sharedMetrics {
    static SFMetrics *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [SFMetrics new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        memset(_counters, 0x00, sizeof(_counters));
        memset(_meters, 0x00, sizeof(_meters));
    }
    return self;
}

- (void)enumerateCountersUsingBlock:(void (^)(SFMetricsKey key, NSInteger count))block {
    for (SFMetricsKey key = SFMetricsFirstCounterKey; key <= SFMetricsLastCounterKey; key++) {
        block(key, _counters[key - SFMetricsFirstCounterKey]);
    }
}

- (void)enumerateMetersUsingBlock:(void (^)(SFMetricsKey key, const SFMetricsMeter *meter))block {
    for (SFMetricsKey key = SFMetricsFirstMeterKey; key <= SFMetricsLastMeterKey; key++) {
        block(key, &_meters[key - SFMetricsFirstMeterKey]);
    }
}

- (void)reset {
    @synchronized(self) {
        memset(_counters, 0x00, sizeof(_counters));
        memset(_meters, 0x00, sizeof(_meters));
    }
}

- (void)count:(SFMetricsKey)counterKey {
    [self count:counterKey value:1];
}

- (void)count:(SFMetricsKey)counterKey value:(NSInteger)value {
    SFDebug(@"Count %ld for key %@", value, SFMetricsMetricName(counterKey));
    if (counterKey < SFMetricsFirstCounterKey || counterKey > SFMetricsLastCounterKey) {
        SFDebug(@"Counter key %ld is out of range", counterKey);
        return;
    }
    @synchronized(self) {
        _counters[counterKey - SFMetricsFirstCounterKey] += value;
    }
}

- (void)measure:(SFMetricsKey)meterKey value:(double)value {
    SFDebug(@"Measure %lf for key %@", value, SFMetricsMetricName(meterKey));
    if (meterKey < SFMetricsFirstMeterKey || meterKey > SFMetricsLastMeterKey) {
        SFDebug(@"Meter key %ld is out of range", meterKey);
        return;
    }
    @synchronized(self) {
        SFMetricsMeter *meter = &_meters[meterKey - SFMetricsFirstMeterKey];
        meter->sum += value;
        meter->sumsq += value * value;
        meter->count++;
    }
}

@end
