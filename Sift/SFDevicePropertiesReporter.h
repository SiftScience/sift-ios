// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"

/**
 * Device properties are sent to their own queue, which is configured to
 * record only difference (we assume that device properties are rarely
 * changed).
 */
extern NSString * const SFDevicePropertiesReporterQueueIdentifier;
extern const SFQueueConfig SFDevicePropertiesReporterQueueConfig;

/** Report device properties. */
@interface SFDevicePropertiesReporter : NSObject

/** Report device properties through its own queue. */
- (void)report;

/** @name For testing. */

/** Create a report. */
- (NSDictionary *)createReport;

/** @return a persistent ID of this device. */
- (NSString *)getPersistentUniqueId;

@end
