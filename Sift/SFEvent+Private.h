// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFCompatibility.h"
#import "SFEvent.h"
#import "SFIosAppState.h"
#import "SFIosDeviceProperties.h"

@interface SFEvent ()

/** An unique ID. */
@property NSString *installationId;

/** Device properties.  Default to nil. */
@property SF_GENERICS(NSDictionary, NSString *, NSString *) *deviceProperties;

/** Structured iOS app state.  Default to nil. */
@property SFHtDictionary *iosAppState;

/** Structured iOS device properties.  Default to nil. */
@property SFHtDictionary *iosDeviceProperties;

/** Internal metrics.  Default to nil. */
@property SF_GENERICS(NSDictionary, NSString *, NSString *) *metrics;

/** Compare event contents except `time`. */
- (BOOL)isEssentiallyEqualTo:(SFEvent *)event;

/** Create a JSON-encoded list request object. */
+ (NSData *)listRequest:(NSArray *)events;

/** @return YES if event contents make sense. */
- (BOOL)sanityCheck;

@end
