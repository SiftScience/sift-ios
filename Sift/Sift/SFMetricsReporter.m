// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#include <math.h>

#import "SFDebug.h"
#import "SFMetrics.h"
#import "SFUtils.h"
#import "Sift.h"

#import "SFMetricsReporter.h"

// TODO(clchiou): Handle app lifecycle (and persist metrics data).

static NSString * const SFMetricsReporterPath = @"/sift/metrics";
static NSString * const SFMetricsReporterType = @"sift";

@interface SFMetricsReporter ()

- (NSDictionary *)createReport:(NSDate *)startDate duration:(CFTimeInterval)duration;

@end

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
    SFMetrics *metrics = [SFMetrics sharedMetrics];
    @synchronized(metrics) {
        NSDate *nowDate = [NSDate date];
        CFTimeInterval now = CACurrentMediaTime();
        CFTimeInterval duration = now - _lastReportingTime;
        if (duration <= 0.0) {
            SFDebug(@"CACurrentMediaTime goes backward");
            [[SFMetrics sharedMetrics] count:SFMetricsKeyNumMiscErrors];
        } else {
            SFDebug(@"Create report of metrics from %@ with duration %g", _lastReportingDate, duration);
            report = [self createReport:_lastReportingDate duration:duration];
        }
        [metrics reset];
        _lastReportingDate = nowDate;
        _lastReportingTime = now;
    }
    if (report) {
        [[Sift sharedSift] appendEvent:[SFEvent eventWithPath:SFMetricsReporterPath mobileEventType:SFMetricsReporterType userId:nil fields:report]];
    }
}

- (NSDictionary *)createReport:(NSDate *)startDate duration:(CFTimeInterval)duration {
    SFMetrics *metrics = [SFMetrics sharedMetrics];
    NSMutableDictionary *counters = [NSMutableDictionary new];
    [metrics enumerateCountersUsingBlock:^(SFMetricsKey key, NSInteger count) {
        [counters setObject:[NSNumber numberWithInteger:count] forKey:SFMetricsMetricName(key)];
    }];
    NSMutableDictionary *meters = [NSMutableDictionary new];
    [metrics enumerateMetersUsingBlock:^(SFMetricsKey key, const SFMetricsMeter *meter) {
        NSMutableDictionary *data = [NSMutableDictionary new];
        [data setObject:[NSNumber numberWithInteger:meter->count] forKey:@"count"];
        if (meter->count > 0) {
            [data setObject:[NSNumber numberWithDouble:(meter->sum / meter->count)] forKey:@"average"];
        }
        if (meter->count > 1) {
            double stdev = sqrt((meter->sumsq - meter->sum * meter->sum / meter->count) / (meter->count - 1));
            [data setObject:[NSNumber numberWithDouble:stdev] forKey:@"stdev"];
        }
        [meters setObject:data forKey:SFMetricsMetricName(key)];
    }];
    return @{@"start": [NSNumber numberWithDouble:[startDate timeIntervalSince1970]], @"duration": [NSNumber numberWithDouble:duration], @"counters": counters, @"meters": meters};
}

@end
