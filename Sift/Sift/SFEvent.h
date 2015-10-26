// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

NSDictionary *SFEventMakeEvent(NSInteger time, NSString *path, NSString *mobileEventType, NSString *userId, NSDictionary *fields);

@interface SFRecordIoToListRequestConverter : NSObject

- (BOOL)start:(NSFileHandle *)listRequest;

- (BOOL)convert:(NSFileHandle *)recordIo;

- (BOOL)end;

@end