// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

BOOL SFRecordIoAppendRecord(NSFileHandle *handle, NSDictionary *record);

NSDictionary *SFRecordIoReadRecord(NSFileHandle *handle);

NSData *SFRecordIoReadRecordData(NSFileHandle *handle);

NSDictionary *SFRecordIoReadLastRecord(NSFileHandle *handle);

NSData *SFRecordIoReadLastRecordData(NSFileHandle *handle);
