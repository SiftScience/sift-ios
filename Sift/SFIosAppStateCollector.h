// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

/** Collect app states behind the scene. */
@interface SFIosAppStateCollector : NSObject

- (instancetype)initWithArchivePath:(NSString *)archivePath;

- (void)archive;

@end
