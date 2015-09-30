// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#include <math.h>

#import "SFMetrics.h"
#import "SFUtil.h"
#import "Sift.h"

#import "SFMetricsReporter.h"

// TODO(clchiou): Handle app lifecycle (and persist metrics data).

static const NSTimeInterval SFMetricsReportingInterval = 60.0;  // 1 minute.
static const NSTimeInterval SFMetricsReportingMinInterval = 1.0;

@interface SFMetricsReporter ()

- (void)enqueueReport:(NSTimer *)timer;

- (void)report;

@end

@implementation SFMetricsReporter {
    SFMetrics *_metrics;

    NSDate *_lastReportingDate;
    CFTimeInterval _lastReportingTime;

    NSOperationQueue *_queue;
}

- (instancetype)initWithMetrics:(SFMetrics *)metrics queue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        _metrics = metrics;
        _queue = queue;
        _lastReportingDate = [NSDate date];
        _lastReportingTime = CACurrentMediaTime();

        NSTimer *timer = [NSTimer timerWithTimeInterval:SFMetricsReportingInterval target:self selector:@selector(enqueueReport:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (void)enqueueReport:(NSTimer *)timer {
    [_queue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(report) object:nil]];
}

- (void)report {
    // TODO(clchiou): Should we have a separate timer for these measurements?
    if (self.manager) {
        [_metrics measure:SFMetricsKeyEventFileManagerNumEventStores value:self.manager.numEventStores];
    }

    @synchronized(_metrics) {
        NSDate *nowDate = [NSDate date];
        CFTimeInterval now = CACurrentMediaTime();
        NSDictionary *event = [self createReport:_lastReportingDate duration:(now - _lastReportingTime)];
        if (!event) {
            return;
        }
        [[Sift sharedInstance] event:event];
        [_metrics reset];
        _lastReportingDate = nowDate;
        _lastReportingTime = now;
    }
}

- (NSDictionary *)createReport:(NSDate *)startDate duration:(CFTimeInterval)duration {
    @synchronized(self) {
        SFDebug(@"Create report of metrics from %@ with duration %g", startDate, duration);
        if (duration <= 0.0) {
            SFDebug(@"CACurrentMediaTime goes backward");
            return nil;
        }
        if (duration < SFMetricsReportingMinInterval) {
            SFDebug(@"Too close to last time we report");
            return nil;
        }

        @synchronized(_metrics) {
            NSMutableDictionary *counters = [NSMutableDictionary new];
            [_metrics enumerateCountersUsingBlock:^(SFMetricsKey key, NSInteger count) {
                [counters setObject:[NSNumber numberWithInteger:count] forKey:SFMetricsMetricName(key)];
            }];
            NSMutableDictionary *meters = [NSMutableDictionary new];
            [_metrics enumerateMetersUsingBlock:^(SFMetricsKey key, const SFMetricsMeter *meter) {
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
    }
}

@end
