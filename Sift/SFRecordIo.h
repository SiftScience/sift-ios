// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/**
 * Helper functions for manipulating Record IO files.
 *
 * A record is just any `NSDictionary` object that can be serialized
 * into a JSON string.
 *
 * A Record IO file is simply a concatenation of meta data and records;
 * you may always read records consecutively from the start of a file.
 */

/**
 * Append a record to a Record IO file.  If it fails, the file contents
 * might be corrupted (and you probably should delete that file).
 *
 * @return YES on success.
 */
BOOL SFRecordIoAppendRecord(NSFileHandle *handle, NSDictionary *record);

/**
 * Read and return a record from the current position of the Record IO
 * file handle (so if you seek to an invalid position, this function
 * will fail or return garbage).  After it returns, the position points
 * to the start of the next record.
 *
 * @return record or nil on failure.
 */
NSDictionary *SFRecordIoReadRecord(NSFileHandle *handle);

/**
 * Same as `SFRecordIoReadRecord` but does not deserialize data and
 * return a `NSData` object instead.  It does not guarantee that you may
 * later deserialize the `NSData` object back into a record.
 *
 * @return raw record data or nil on failure.
 */
NSData *SFRecordIoReadRecordData(NSFileHandle *handle);

/**
 * Seek and return the last record of the Record IO file.  After it
 * returns, the position points to the end of the file.
 *
 * @return record or nil on failure.
 */
NSDictionary *SFRecordIoReadLastRecord(NSFileHandle *handle);

/**
 * Same as `SFRecordIoReadLastRecord` but does not deserialize data and
 * return a `NSData` object instead.  It does not guarantee that you may
 * later deserialize the `NSData` object back into a record.
 *
 * @return raw record data or nil on failure.
 */
NSData *SFRecordIoReadLastRecordData(NSFileHandle *handle);
