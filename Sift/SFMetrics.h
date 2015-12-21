// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * The predefined list of counters.
 *
 * A counter counts the number of an event.
 */
#define SF_METRICS_COUNTERS(BIN_OP) \
    SF_METRICS_MAKE(NumDataCorruptionErrors) BIN_OP \
    SF_METRICS_MAKE(NumFileIoErrors) BIN_OP \
    SF_METRICS_MAKE(NumFileOperationErrors) BIN_OP \
    SF_METRICS_MAKE(NumHttpErrors) BIN_OP \
    SF_METRICS_MAKE(NumMiscErrors) BIN_OP \
    SF_METRICS_MAKE(NumNetworkErrors) BIN_OP \
    SF_METRICS_MAKE(NumEventsDropped)

/**
 * The predefined list of meters.
 *
 * A meter makes measurements and records the first and the second
 * moment (for calculating mean and variance).
 *
 * NOTE: At the moment there is no meters.
 */
#define SF_METRICS_METERS(BIN_OP) \
    SF_METRICS_MAKE(PlaceHolderForNoMeters)

#define SF_COMMA ,

/**
 * List of counter and meter keys, which you use to refer them.
 *
 * The counters and meters are predefined and their space are
 * preallocated.  If you would like to add more counters or meters, put
 * them to the respective predefined list above.
 */
typedef NS_ENUM(NSInteger, SFMetricsKey) {
#define SF_METRICS_MAKE(name) SFMetricsKey ## name
    SF_METRICS_COUNTERS(SF_COMMA),
    SF_METRICS_METERS(SF_COMMA),
#undef SF_METRICS_MAKE
    SFMetricsNumMetrics,
};

/**
 * @return string representation (useful when printing them out) of the
 * key, or nil if it is not a valid key.
 */
NSString *SFMetricsMetricName(SFMetricsKey key);

/**
 * A meter records the sum of measurements, the sum of the squares of
 * measurements, and the number of measurements.  Together they can be
 * used to calculate mean and variance.
 *
 * TODO(clchiou): It's probably not a great idea to report mean/stdev.
 */
typedef struct {
    double sum;
    double sumsq;
    NSInteger count;
} SFMetricsMeter;

/**
 * Count, measure, and record metric data.  You should use the shared
 * metrics object rather than creating one.
 *
 * The metric data are zero-initialized.
 */
@interface SFMetrics : NSObject

/** @return the shared metrics object. */
+ (instancetype)sharedInstance;

/**
 * Count an event of the given counter key, or do nothing if it is not a
 * valid counter key.
 */
- (void)count:(SFMetricsKey)counterKey;

/**
 * Count number of occurrence of an event of the given counter key, or
 * do nothing if it is not a valid counter key.
 */
- (void)count:(SFMetricsKey)counterKey value:(NSInteger)value;

/**
 * Make a measurement for the given meter key, of do nothing if it is
 * not a valid meter key.
 */
- (void)measure:(SFMetricsKey)meterKey value:(double)value;

/** Enumerate counter data. */
- (void)enumerateCountersUsingBlock:(void (^)(SFMetricsKey key, NSInteger count))block;

/** Enumerate meter data. */
- (void)enumerateMetersUsingBlock:(void (^)(SFMetricsKey key, const SFMetricsMeter *meter))block;

/** Reset all metric data to zero. */
- (void)reset;

@end
