// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * An event has: time, path, (mobile event) type, user ID, and a
 * dictionary of fields.  All of them are optional.  You may alter them
 * after the object creation (through properties below) but before the
 * event object is append to an event queue.
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

/** User ID.  Default to nil. */
@property NSString *userId;

/** Custom event fields.  Default to nil. */
@property NSDictionary *fields;

@end
