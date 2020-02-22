// Copyright (c) 2016 Sift Science. All rights reserved.

// This is a public header.

@import Foundation;

#import "SiftCompatibility.h"

/**
 * An event has: time, (mobile event) type, path, user ID, and a
 * dictionary of custom fields.
 */
@interface SiftEvent : NSObject <NSCoding>

/** Create an `SFEvent` object.  All arguments are nullable. */
+ (SiftEvent *)eventWithType:(NSString *)type path:(NSString *)path fields:(NSDictionary *)fields;

/** @name Event properties. */

/** Event time.  Default to now. */
@property uint64_t time;

/** Event type.  Default to nil. */
@property NSString *type;

/** Event path.  Default to nil. */
@property NSString *path;

/**
 * User ID.
 *
 * If not set, the event queue will use the user ID set in the shared
 * Sift object.
 */
@property NSString *userId;

/**
 * Custom event fields; both key and value must be string typed.
 * Default to nil.
 */
@property SF_GENERICS(NSDictionary, NSString *, NSString *) *fields;

@end
