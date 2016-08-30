// Copyright (c) 2016 Sift Science. All rights reserved.

// This is a public header.

#import <Foundation/Foundation.h>

#import "SFEvent.h"
#import "SFQueueConfig.h"

/**
 * This is the main interface you interact with Sift.
 *
 * The Sift object is stateful and is configured post initialization.
 * See the "Configurations" section below for details.
 *
 * The Sift object is built on top of event queues.  Every queue is
 * identified by an `identifier` and has a `SFQueueConfig` object.
 * You should plan event queues based on batching and latency needs,
 * not by the actual event types you are sending to the queues (an
 * upload collects events from all the queues and submits them in one
 * request; so there is no point to create an event queue solely based
 * on types of events).  Note: There is a default event queue and that
 * is probably all you need.
 *
 * Methods return YES on success.
 */
@interface Sift : NSObject

/** @return the shared instance of Sift. */
+ (instancetype)sharedInstance;

@property (readonly) NSString *sdkVersion;

/**
 * Add an event queue that did not exist prior to the call.
 *
 * @return YES on success.
 */
- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config;

/**
 * Remove an event queue.
 *
 * @return YES on success.
 */
- (BOOL)removeEventQueue:(NSString *)identifier;

/**
 * Send an event to the queue identified by `identifier`, or fail if the
 * queue was not created prior to the call.
 *
 * If set `withLocation` to YES, Sift will automatically augment the
 * event with location data.
 *
 * @return YES on success.
 */
- (BOOL)appendEvent:(SFEvent *)event withLocation:(BOOL)withLocation toQueue:(NSString *)identifier;

/**
 * Same as above but use the default queue (most of the time you should
 * probably use this).
 */
- (BOOL)appendEvent:(SFEvent *)event withLocation:(BOOL)withLocation;

/** Same as above but set `withLocation` to NO. */
- (BOOL)appendEvent:(SFEvent *)event;

/**
 * @name Configurations.
 *
 * You should configure `accountId`, `beaconKey`, and `userId`.
 */

/**
 * The default queue identifier.
 *
 * This is used when you call `appendEvent` without an identifier.
 */
@property NSString *defaultQueueIdentifier;

/**
 * Your account ID.  Default to nil.
 *
 * NOTE: This is persisted to device's storage.
 */
@property NSString *accountId;

/**
 * Your beacon key.  Default to nil.
 *
 * NOTE: This is persisted to device's storage.
 */
@property NSString *beaconKey;

/**
 * User ID.  Default to nil.
 *
 * NOTE: This is persisted to device's storage.
 */
@property NSString *userId;

/**
 * @name Integration helpers.
 *
 * The methods and properties of this section are useful for validating
 * integration (and sometimes useful in production).
 */

/**
 * Request an upload.  Sift will collect events from every queue to make
 * an upload batch, and put that batch in upload queue.  When collecting
 * events, Sift will comply with their queue config (so the latest event
 * might not be collected).
 *
 * If one of `accountId`, `beaconId`, or `serverUrlFormat` property is
 * nil, this method will do nothing.
 *
 * @return YES on success.
 */
- (BOOL)upload;

/** Same as above but disregard queue config if `force` is YES. */
- (BOOL)upload:(BOOL)force;

/**
 * The API endpoint that will receive the upload requests.
 *
 * You may set this to a test server while you are integrating your app
 * with Sift to validate that your integration works.
 *
 * Default to
 *   "https://api3.siftscience.com/v3/accounts/%@/mobile_events"
 * where "%@" will be substituted with `accountId`.
 */
@property NSString *serverUrlFormat;

@end
