// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "Sift.h"

@interface SFUploader : NSObject <NSURLSessionTaskDelegate>

- (instancetype)initWithArchivePath:(NSString *)archivePath sift:(Sift *)sift;

/** Persist uploader state to disk. */
- (void)archive;

/** Upload events to the server. */
- (void)upload:(NSArray *)events;

@end
