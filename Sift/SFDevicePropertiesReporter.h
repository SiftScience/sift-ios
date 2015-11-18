// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"

extern NSString * const SFDevicePropertiesReporterQueueIdentifier;
extern const SFQueueConfig SFDevicePropertiesReporterQueueConfig;

/** Report device properties. */
@interface SFDevicePropertiesReporter : NSObject

/** Report device properties through its own queue. */
- (void)report;

@end
