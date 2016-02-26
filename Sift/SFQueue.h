// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFEvent.h"
#import "SFQueueConfig.h"
#import "Sift.h"

/**
 * A queue is simply a `NSArray` of `SFEvent` objects with an
 * `SFQueueConfig` policy object.
 */
@interface SFQueue : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config archivePath:(NSString *)archivePath sift:(Sift *)sift;

/**
 * Persist events to disk (call this when app enters into background).
 *
 * NOTE: This method is blocking (don't call it in the main thread).
 */
- (void)archive;

/** Append an event to the queue. */
- (void)append:(SFEvent *)event;

/** @return YES if queued events are ready for upload. */
- (BOOL)readyForUpload;

/** Transfer ownership of the queue of events to the caller. */
- (NSArray *)transfer;

@end
