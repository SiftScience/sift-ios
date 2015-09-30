// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileManager.h"

@interface SFMetricsReporter : NSObject

- (instancetype)initWithMetrics:(SFMetrics *)metrics queue:(NSOperationQueue *)queue;

- (NSDictionary *)createReport:(NSDate *)startDate duration:(CFTimeInterval)duration;

@property SFEventFileManager *manager;

@end