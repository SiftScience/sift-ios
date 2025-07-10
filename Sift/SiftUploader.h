// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "Sift.h"

NS_EXTENSION_UNAVAILABLE_IOS("SiftUploader is not supported for iOS extensions.")
@interface SiftUploader : NSObject <NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (instancetype)initWithArchivePath:(NSString *)archivePath sift:(Sift *)sift;

/** Persist uploader state to disk. */
- (void)archive;

/** Upload events to the server. */
- (void)upload:(NSArray *)events;

/** Pause sending events*/
- (void)pause;

/** Resume sending events*/
- (void)resume;

@end
