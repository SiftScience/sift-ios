// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFEventsFileManager()

// Method with `NeedLocking` suffix do not acquire any lock, and the caller should acquire locks before calling them.

- (void)createEventsDirNeedLocking;

- (void)createCurrentEventsFileNeedLocking;

- (BOOL)shouldRotateCurrentEventsFileNeedLocking;

- (void)rotateCurrentEventsFileNeedLocking;

- (NSArray *)listEventsFilePathsNeedLocking;

- (NSString *)findNextEventsFilePathNeedLocking;

// Visible for testing.
@property (readonly, nonatomic) NSFileManager *manager;
@property (readonly, nonatomic) NSString *eventsDirPath;

@end