// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreMotion;
@import Foundation;

/** Collect app states behind the scene. */
@interface SiftIosAppStateCollector : NSObject

- (instancetype)initWithArchivePath:(NSString *)archivePath;

- (void)archive;

/** Collect app state. */
- (void)collectWithTitle:(NSString *)title andTimestamp:(SFTimestamp)now NS_EXTENSION_UNAVAILABLE_IOS("collectWithTitle is not supported for iOS extensions.");

@property (nonatomic) BOOL disallowCollectingLocationData;

@end
