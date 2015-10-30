// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#include <math.h>

#import "SFDebug.h"
#import "SFMetrics.h"
#import "SFUtil.h"
#import "Sift.h"

#import "SFMetricsReporter.h"

// TODO(clchiou): Handle app lifecycle (and persist metrics data).

// TODO(clchiou): Make this interval configurable.
static const NSTimeInterval SFMetricsReporterInterval = 60.0;  // 1 minute.

static NSString * const SFMetricsReporterPath = @"/sift/metrics_reporter";
static NSString * const SFMetricsReporterType = @"sift_metrics_report";

@interface SFMetricsReporter ()

- (NSDictionary *)createReport:(NSDate *)startDate duration:(CFTimeInterval)duration;

- (void)enqueueReport:(NSTimer *)timer;

- (void)report;

@end

@implementation SFMetricsReporter {
    NSDate *_lastReportingDate;
    CFTimeInterval _lastReportingTime;
    NSOperationQueue *_operationQueue;
}

- (instancetype)initWithOperationQueue:(NSOperationQueue *)operationQueue {
    self = [super init];
    if (self) {
        _operationQueue = operationQueue;
        _lastReportingDate = [NSDate date];
        _lastReportingTime = CACurrentMediaTime();

        NSTimer *timer = [NSTimer timerWithTimeInterval:SFMetricsReporterInterval target:self selector:@selector(enqueueReport:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)enqueueReport:(NSTimer *)timer {
    [_operationQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(report) object:nil]];
}

- (void)report {
    @synchronized(self) {
        // NOTE: SFMetrics object use itself for locking.
        SFMetrics *metrics = [SFMetrics sharedMetrics];
        @synchronized(metrics) {
            NSDate *nowDate = [NSDate date];
            CFTimeInterval now = CACurrentMediaTime();
            CFTimeInterval duration = now - _lastReportingTime;
            if (duration <= 0.0) {
                SFDebug(@"CACurrentMediaTime goes backward");
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumMiscErrors];
                return;
            }
            SFDebug(@"Create report of metrics from %@ with duration %g", _lastReportingDate, duration);
            NSDictionary *report = [self createReport:_lastReportingDate duration:duration];
            if (!report) {
                return;
            }
            [[Sift sharedSift] appendEvent:SFMetricsReporterPath mobileEventType:SFMetricsReporterType userId:nil fields:report];
            [metrics reset];
            _lastReportingDate = nowDate;
            _lastReportingTime = now;
        }
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
