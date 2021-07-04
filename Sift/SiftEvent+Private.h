// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SiftCompatibility.h"
#import "SiftEvent.h"
#import "SiftIosAppState.h"
#import "SiftIosDeviceProperties.h"

@interface SiftEvent ()

/** An unique ID. */
@property NSString *installationId;

/** Device properties.  Default to nil. */
@property SF_GENERICS(NSDictionary, NSString *, NSString *) *deviceProperties;

/** Structured iOS app state.  Default to nil. */
@property NSMutableDictionary *iosAppState;

/** Structured iOS device properties.  Default to nil. */
@property NSMutableDictionary *iosDeviceProperties;

/** Internal metrics.  Default to nil. */
@property SF_GENERICS(NSDictionary, NSString *, NSString *) *metrics;

/** Compare event contents except `time`. */
- (BOOL)isEssentiallyEqualTo:(SiftEvent *)event;

/** Create a JSON-encoded list request object. */
+ (NSData *)listRequest:(NSArray *)events;

/** @return YES if event contents make sense. */
- (BOOL)sanityCheck;

@end
