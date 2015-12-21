// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * An event has: time, path, (mobile event) type, user ID, and a
 * dictionary of fields.  All of them except user ID are optional.  You
 * may alter them after the object creation (through properties below)
 * but before the event object is append to an event queue.
 *
 * NOTE: User ID is _NOT_ optional.
 */
@interface SFEvent : NSObject

/** Create an `SFEvent` object.  All arguments are nullable. */
+ (SFEvent *)eventWithPath:(NSString *)path mobileEventType:(NSString *)mobileEventType userId:(NSString *)userId fields:(NSDictionary *)fields;

/** @name Event properties. */

/** Event time.  Default to now. */
@property NSInteger time;

/** Event path.  Default to nil. */
@property NSString *path;

/** Event type.  Default to nil. */
@property NSString *mobileEventType;

/** User ID.  Default to nil.  It is _NOT_ optional. */
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

@end

/** @return true if userId is nil or an empty string. */
BOOL SFEventIsEmptyUserId(NSString *userId);