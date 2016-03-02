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
 * @return YES on success.
 */
- (BOOL)appendEvent:(SFEvent *)event toQueue:(NSString *)identifier;

/**
 * Same as above but use the default queue (most of the time you should
 * probably use this).
 */
- (BOOL)appendEvent:(SFEvent *)event;

/**
 * Start collecting motion data after `delay` seconds for `period`
 * seconds of time, and collect `numSamples` of data per second.
 */
- (void)collectMotionData:(NSTimeInterval)delay period:(NSTimeInterval)period numSamples:(int)numSamples;

/**
 * @name Configurations.
 *
 * At minimum you should configure `accountId`, `beaconKey`, and
 * `userId`.
 */

/** Your account ID.  Default to nil. */
@property NSString *accountId;

/** Your beacon key.  Default to nil. */
@property NSString *beaconKey;

/**
 * User ID.  Default to nil.
 *
 * All the events you send are associated with a user - if you don't set
 * this, the events you send will be dropped at the server side (this
 * might be unfortunate for apps that don't identify individual users).
 */
@property NSString *userId;

/**
 * @name Integration helpers.
 *
 * The methods and properties of this section are useful for validating
 * integration (and sometimes useful in production).
 */

/**
 * Issue an upload of events and return after the HTTP request is sent,
 * but before we receive the HTTP response.
 *
 * If one of `accountId`, `beaconId`, `userId`, or `serverUrlFormat`
 * property is nil, this method will do nothing.
 *
 * @return YES on success.
 */
- (BOOL)upload;

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
