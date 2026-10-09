//
//  XCTestCase+SiftCollector.h
//  SiftTests
//
//  Copyright © 2026 Sift Science. All rights reserved.
//

@import XCTest;

#import "SiftEvent.h"
#import "SiftEvent+Private.h"
#import "SiftIosAppStateCollector.h"

/** Helpers for tests that observe SiftIosAppStateCollector collections. */
@interface XCTestCase (SiftCollector)

/**
 * A collector whose periodic timer won't collect during the test (a collection
 * "just happened"), with the production rate limit.
 */
- (SiftIosAppStateCollector *)makeQuietCollector;

/**
 * Stub -[Sift appendEvent:] for the rest of the test: events are recorded
 * instead of queued. Restored on teardown. Events from any collector are recorded.
 */
- (void)startCapturingAppendedEvents;

/** Number of captured events whose window_root_view_controller_titles is @[title]. */
- (NSUInteger)capturedEventCountWithTitle:(NSString *)title;

/** Wait until every block already queued on the main queue has run. */
- (void)flushMainQueue;

/**
 * Wait until every collection already requested from `collector` has appended
 * its event, including the collector's heading delay (about 4.5 s).
 */
- (void)drainCollector:(SiftIosAppStateCollector *)collector;

@end
