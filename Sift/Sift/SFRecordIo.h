// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

BOOL SFRecordIoAppendRecord(NSFileHandle *handle, NSDictionary *record);

NSDictionary *SFRecordIoReadLastRecord(NSFileHandle *handle);
