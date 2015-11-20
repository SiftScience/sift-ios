// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueDirs.h"

/**
 * Collect and upload events from the Record IO files of queues.  After
 * the upload succeeded, delete those Record IO files.
 */
@interface SFUploader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

/**
 * Create an uploader object.  It will keep update state in files under
 * `rootDirPath` (which should not conflict with other directories).
 */
- (instancetype)initWithRootDirPath:(NSString *)rootDirPath queueDirs:(SFQueueDirs *)queueDirs operationQueue:(NSOperationQueue *)operationQueue config:(NSURLSessionConfiguration *)config;

/**
 * Collect events from queues and upload them in one list request.
 *
 * When an upload is in progress, `SFUploader` will ignore your call to
 * this method, unless `force` is YES.  NOTE: If you force an upload,
 * you may risk uploading duplicated events.
 *
 * @return YES on success.
 */
- (BOOL)upload:(NSString *)serverUrlFormat accountId:(NSString *)accountId beaconKey:(NSString *)beaconKey force:(BOOL)force;

/** Clean up outdated upload state files. */
- (void)cleanup;

@end
