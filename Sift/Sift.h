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
 * This method is blocking.
 *
 * @return YES on success.
 */
- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config;

/**
 * Remove an event queue and optionally remove the data files of the
 * queue if `purge` is YES.
 *
 * This method is blocking.
 *
 * @return YES on success.
 */
- (BOOL)removeEventQueue:(NSString *)identifier purge:(BOOL)purge;

/**
 * Send an event to the queue identified by `identifier`, or fail if the
 * queue was not created prior to the call.
 *
 * This method is _not_ blocking.
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
 * The interval at which we issue uploads.  You cancel the upload timer
 * by setting a non-positive value.
 *
 * Default to 60 seconds.
 */
@property (nonatomic) NSTimeInterval uploadPeriod;

/**
 * The interval at which we collect internal metrics and device data.
 * You cancel this timer by setting a non-positive value.
 *
 * Default to 60 seconds.
 */
@property (nonatomic) NSTimeInterval reportPeriod;

/**
 * @name Integration helpers.
 *
 * The methods and properties of this section are useful for validating
 * integration (and sometimes useful in production).
 */

/**
 * Flush out all events.
 *
 * Due to batching, when an event was enqueued, it would not be uploaded
 * just yet even if you request an upload.  This method makes all events
 * become "upload-able" immediately.
 *
 * @return YES on success.
 */
- (BOOL)flush;

/**
 * Issue an upload of events and return after the HTTP request is sent,
 * but before we receive the HTTP response.
 *
 * If `force` is NO, the upload will be ignored if an prior upload is in
 * progress.  NOTE: If you force an upload, you may risk uploading
 * duplicated events.
 *
 * If one of `accountId`, `beaconId`, `userId`, or `serverUrlFormat`
 * property is nil, this method will do nothing.
 *
 * This method is blocking.
 *
 * @return YES on success.
 */
- (BOOL)upload:(BOOL)force;

/** Same as above but with force=NO. */
- (BOOL)upload;

/** Remove all data. */
- (void)removeData;

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
