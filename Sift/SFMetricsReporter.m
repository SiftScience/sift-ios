// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#include <math.h>

#import "SFDebug.h"
#import "SFMetrics.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFMetricsReporter.h"

@implementation SFMetricsReporter {
    NSDate *_lastReportingDate;
    CFTimeInterval _lastReportingTime;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _lastReportingDate = [NSDate date];
        _lastReportingTime = CACurrentMediaTime();
    }
    return self;
}

- (void)report {
    NSDictionary *report = nil;
    // NOTE: SFMetrics object use itself for locking.
    SFMetrics *metrics = [SFMetrics sharedInstance];
    @synchronized(metrics) {
        NSDate *nowDate = [NSDate date];
        CFTimeInterval now = CACurrentMediaTime();
        CFTimeInterval duration = now - _lastReportingTime;
        if (duration <= 0.0) {
            SF_DEBUG(@"CACurrentMediaTime goes backward");
            [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
        } else {
            SF_DEBUG(@"Create report of metrics from %@ with duration %g", _lastReportingDate, duration);
            report = [self createReport:metrics startDate:_lastReportingDate duration:duration];
        }
        [metrics reset];
        _lastReportingDate = nowDate;
        _lastReportingTime = now;
    }
    if (report) {
        SFEvent *event = [SFEvent new];
        event.metrics = report;
        [[Sift sharedInstance] appendEvent:event];
    }
}

- (NSDictionary *)createReport:(SFMetrics *)metrics startDate:(NSDate *)startDate duration:(CFTimeInterval)duration {
    NSMutableDictionary *report = [NSMutableDictionary new];
    [metrics enumerateCountersUsingBlock:^(SFMetricsKey key, NSInteger count) {
        if (count <= 0) {
            return;
        }
        NSString *snakeKey = SFCamelCaseToSnakeCase(SFMetricsMetricName(key));
        [report setObject:[NSNumber numberWithInteger:count] forKey:snakeKey];
    }];
    [metrics enumerateMetersUsingBlock:^(SFMetricsKey key, const SFMetricsMeter *meter) {
        if (meter->count <= 0) {
            return;
        }
        NSString *snakeKey = SFCamelCaseToSnakeCase(SFMetricsMetricName(key));
        [report setObject:[NSNumber numberWithInteger:meter->count] forKey:[snakeKey stringByAppendingString:@".count"]];
        [report setObject:[NSNumber numberWithInteger:meter->sum] forKey:[snakeKey stringByAppendingString:@".sum"]];
        [report setObject:[NSNumber numberWithInteger:meter->sumsq] forKey:[snakeKey stringByAppendingString:@".sum_square"]];
    }];
    [report setObject:[NSNumber numberWithDouble:[startDate timeIntervalSince1970]] forKey:@"start"];
    [report setObject:[NSNumber numberWithDouble:duration] forKey:@"duration"];
    SF_DEBUG(@"Metrics: %@", report);
    return report;
}

@end
