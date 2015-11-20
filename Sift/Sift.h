// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEvent.h"
#import "SFQueueConfig.h"

/**
 * This is the main interface you interact with Sift.
 *
 * Sift objects are centered around event queues.  Every queue is
 * identified by an `identifier` and has a `SFQueueConfig` object.
 * You should plan event queues based on batching and latency needs,
 * not by the actual event types you are sending to the queues (an
 * upload collects events from all the queues and submits them in one
 * request; so there is no point to create an event queue solely based
 * on types of events).  Note: There is a default event queue and that
 * is probably all you need.
 *
 * Configurations: At minimum you need to provide your account ID and
 * beacon key before sending us data.
 *
 * Methods return YES on success.
 */
@interface Sift : NSObject

/** @return the shared instance of Sift. */
+ (instancetype)sharedSift;

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
 * Issue an upload of events and return after the HTTP request is sent,
 * but before we receive the HTTP response.
 *
 * If `force` is NO, the upload will be ignored if an prior upload is in
 * progress.  NOTE: If you force an upload, you may risk uploading
 * duplicated events.
 *
 * If one of `accountId`, `beaconId`, or `serverUrlFormat` property is
 * nil, this method will do nothing.
 *
 * This method is blocking.
 *
 * @return YES on success.
 */
- (BOOL)upload:(BOOL)force;

/** Same as above but with force=NO. */
- (BOOL)upload;

/**
 * @name Configurations.
 *
 * At minimum you should configure `accountId` and `beaconKey`, which
 * default to nil.
 */

/** Your account ID.  Default to nil. */
@property NSString *accountId;

/** Your beacon key.  Default to nil. */
@property NSString *beaconKey;

/**
 * The API endpoint that will receive the upload requests.
 *
 * You may set this to a test server while you are integrating your app
 * with Sift to validate that your integration works.
 *
 * Default to
 *   "https://api3.siftscience.com/v3/accounts/%@/mobile_events"
 * where "%@" will be interpolated to `accountId`.
 */
@property NSString *serverUrlFormat;

/**
 * The interval at which we issue uploads.  You cancel the upload timer
 * by setting a non-positive value.
 *
 * Default to 60 seconds.
 */
@property (nonatomic) NSTimeInterval uploadPeriod;

/**
 * The interval at which we collect our internal metrics.  You cancel
 * this timer by setting a non-positive value.
 *
 * Default to 60 seconds.
 */
@property (nonatomic) NSTimeInterval reportMetricsPeriod;

@end
