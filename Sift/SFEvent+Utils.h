// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEvent.h"

@interface SFEvent (Utils)

/** Convert an `SFEvent` into a raw event dictionary. */
- (NSDictionary *)makeEvent;

@end

/**
 * Merge a series of Record IO files of JSON records and convert them
 * into a single list request JSON object.
 *
 * We are tackling scenarios that Record IO files are guarded by locks
 * that we may not acquire them all simultaneously.  In light of this,
 * instead of providing a conversion function taking a series of Record
 * IO file handles that you have to acquire locks for all of them prior
 * to the call, we provide a (stateful) class to which you may feed each
 * Record IO file handle one by one, making acquiring respective locks
 * easier.
 *
 * If any of the methods has failed (returning NO), the output file
 * contents might be corrupted and should not be used.
 */
@interface SFRecordIoToListRequestConverter : NSObject

/**
 * Set the output file handle for the list request and mark the start of
 * conversion process.  This must be called before any other methods,
 * and should be called just once.
 *
 * @return YES on success.
 */
- (BOOL)start:(NSFileHandle *)listRequest;

/**
 * Feed one Record IO file of JSON records to the converter.
 *
 * @return YES on success.
 */
- (BOOL)convert:(NSFileHandle *)recordIo;

/**
 * Mark the end of the conversion process and write out remaining list
 * request JSON contents.
 *
 * @return YES on success.
 */
- (BOOL)end;

@end
