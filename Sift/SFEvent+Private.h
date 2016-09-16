// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFEvent.h"
#import "SFIosDeviceProperties.h"

@interface SFEvent ()

/** Device properties.  Default to nil. */
@property NSDictionary<NSString *, NSString *> *deviceProperties;

/** Structured iOS device properties.  Default to nil. */
@property SFIosDeviceProperties *iosDeviceProperties;

/** Internal metrics.  Default to nil. */
@property NSDictionary<NSString *, NSString *> *metrics;

/** Compare event contents except `time`. */
- (BOOL)isEssentiallyEqualTo:(SFEvent *)event;

/** Create a JSON-encoded list request object. */
+ (NSData *)listRequest:(NSArray *)events;

/** @return YES if event contents make sense. */
- (BOOL)sanityCheck;

@end