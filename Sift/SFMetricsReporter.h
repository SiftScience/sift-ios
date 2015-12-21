// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * Use the default `SFMetrics` object and the default `Sift` object for
 * collecting and reporting metrics.
 */
@interface SFMetricsReporter : NSObject

/**
 * Collect and report metrics through the default event queue, and then
 * reset the metrics data.
 */
- (void)report:(NSString *)userId;

/** @name For testing. */

/** Create report. */
- (NSDictionary *)createReport:(SFMetrics *)metrics startDate:(NSDate *)startDate duration:(CFTimeInterval)duration;

@end
