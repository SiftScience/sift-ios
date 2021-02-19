// Copyright (c) 2016 Sift Science. All rights reserved.]

@import Foundation;
@import CoreLocation;

#import "SiftIosAppStateCollector.h"

/** Private methods of `SiftIosAppStateCollector`. */
@interface SiftIosAppStateCollector ()

/** _serialSuspend Count. */
@property int serialSuspendCounter;

/** Load archived data. */
- (void)unarchive;

/**
 * Request to collect app state.
 *
 * The request might be ignored due to rate limiting.
 */
- (void)requestCollectionWithTitle:(NSString *)title;

/**
 * Collect app state if there was no collection in the last SF_MAX_COLLECTION_PERIOD of time and app is active.
 */
- (void)checkAndCollectWhenNoneRecently:(SFTimestamp)now;

/** Collect app state. */
- (void)collectWithTitle:(NSString *)title andTimestamp:(SFTimestamp)now;

/** @return YES if can collect Location data. */
- (BOOL)canCollectLocationData;

@end
