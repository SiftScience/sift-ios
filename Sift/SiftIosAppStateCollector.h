// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreMotion;
@import Foundation;

/** Collect app states behind the scene. */
@interface SiftIosAppStateCollector : NSObject

- (instancetype)initWithArchivePath:(NSString *)archivePath;

- (void)archive;

/** Collect app state. */
- (void)collectWithTitle:(NSString *)title andTimestamp:(SFTimestamp)now NS_EXTENSION_UNAVAILABLE_IOS("collectWithTitle is not supported for iOS extensions.");

/**
 * Record `title` as the manual label, used instead of any per-event title
 * in all later collections. Does not request a collection.
 *
 * `nil`, empty or non-string values reset the label.
 */
- (void)setManualTitle:(NSString *)title;

@property (nonatomic) BOOL disallowCollectingLocationData;

/** Pause sending events*/
- (void)pause;

/** Resume sending events*/
- (void)resume;

@end
