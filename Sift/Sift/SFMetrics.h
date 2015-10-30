// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#define SF_METRICS_COUNTERS(BIN_OP) \
    SF_METRICS_MAKE(NumDataCorruptionErrors) BIN_OP \
    SF_METRICS_MAKE(NumFileIoErrors) BIN_OP \
    SF_METRICS_MAKE(NumFileOperationErrors) BIN_OP \
    SF_METRICS_MAKE(NumHttpErrors) BIN_OP \
    SF_METRICS_MAKE(NumMiscErrors) BIN_OP \
    SF_METRICS_MAKE(NumNetworkErrors) BIN_OP \
    SF_METRICS_MAKE(NumEvents) BIN_OP \
    SF_METRICS_MAKE(NumEventsDropped) BIN_OP \
    SF_METRICS_MAKE(NumUploads) BIN_OP \
    SF_METRICS_MAKE(NumUploadsSucceeded)

#define SF_METRICS_METERS(BIN_OP) \
    SF_METRICS_MAKE(RecordSize)

#define SF_COMMA ,

typedef NS_ENUM(NSInteger, SFMetricsKey) {
#define SF_METRICS_MAKE(name) SFMetricsKey ## name
    SF_METRICS_COUNTERS(SF_COMMA),
    SF_METRICS_METERS(SF_COMMA),
#undef SF_METRICS_MAKE
    SFMetricsNumMetrics,
};

typedef struct {
    double sum;
    double sumsq;
    NSInteger count;
} SFMetricsMeter;

NSString *SFMetricsMetricName(SFMetricsKey key);

@interface SFMetrics : NSObject

+ (instancetype)sharedMetrics;

- (void)count:(SFMetricsKey)counterKey;

- (void)count:(SFMetricsKey)counterKey value:(NSInteger)value;

- (void)measure:(SFMetricsKey)meterKey value:(double)value;

- (void)enumerateCountersUsingBlock:(void (^)(SFMetricsKey key, NSInteger count))block;

- (void)enumerateMetersUsingBlock:(void (^)(SFMetricsKey key, const SFMetricsMeter *meter))block;

- (void)reset;

@end
