// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

// TODO(clchiou): Rewrite this (remove timer and make Sift take care of that).
@interface SFMetricsReporter : NSObject

- (instancetype)initWithOperationQueue:(NSOperationQueue *)operationQueue;

@end
