// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SiftEvent.h"
#import "SiftQueueConfig.h"
#import "Sift.h"

/**
 * A queue is simply a `NSArray` of `SFEvent` objects with an
 * `SFQueueConfig` policy object.
 */
NS_EXTENSION_UNAVAILABLE_IOS("SiftQueue is not supported for iOS extensions.")
@interface SiftQueue : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SiftQueueConfig)config archivePath:(NSString *)archivePath sift:(Sift *)sift;

/**
 * Persist events to disk (call this when app enters into background).
 *
 * NOTE: This method is blocking (don't call it in the main thread).
 */
- (void)archive;

/** Append an event to the queue. */
- (void)append:(SiftEvent *)event;

/** @return YES if queued events are ready for upload. */
- (BOOL)readyForUpload;

/** Transfer ownership of the queue of events to the caller. */
- (NSArray *)transfer;

@end
