// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFEvent : NSObject

/** Create an `SFEvent` object. */
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