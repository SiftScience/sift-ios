// Copyright (c) 2016 Sift Science. All rights reserved.

// This is a public header.

#import <Foundation/Foundation.h>

/**
 * An event has: time, (mobile event) type, path, user ID, and a
 * dictionary of custom fields.
 */
@interface SFEvent : NSObject <NSCoding>

/** Create an `SFEvent` object.  All arguments are nullable. */
+ (SFEvent *)eventWithType:(NSString *)type path:(NSString *)path fields:(NSDictionary *)fields;

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
 * Sift object.  It is an error if neither are set.
 */
@property NSString *userId;

/**
 * Custom event fields; both key and value must be string typed.
 * Default to nil.
 */
@property NSDictionary *fields;

/** @name Internal properties of Sift (do not use it!). */

/** Device properties.  Default to nil. */
@property NSDictionary *deviceProperties;

/** Internal metrics.  Default to nil. */
@property NSDictionary *metrics;

/** Compare event contents except `time`. */
- (BOOL)isEssentiallyEqualTo:(SFEvent *)event;

/** @name List request object. */

/** Create a JSON-encoded list request object. */
+ (NSData *)listRequest:(NSArray *)events;

@end
