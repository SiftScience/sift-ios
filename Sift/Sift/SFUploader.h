// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueDirs.h"

/**
 * Collect and upload events from the Record IO files of queues.  After
 * the upload succeeded, delete the Record IO files of those events.
 */
@interface SFUploader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath queueDirs:(SFQueueDirs *)queueDirs operationQueue:(NSOperationQueue *)operationQueue config:(NSURLSessionConfiguration *)config;

/**
 * Collect events from queues and upload them in one list request.
 *
 * When an upload is in progress, `SFUploader` will ignore your call to
 * this method.
 *
 * @return YES on success.
 */
- (BOOL)upload:(NSString *)serverUrlFormat accountId:(NSString *)accountId beaconKey:(NSString *)beaconKey;

@end
