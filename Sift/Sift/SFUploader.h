// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueDirs.h"

@interface SFUploader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (instancetype)initWithServerUrl:(NSString *)serverUrl rootDirPath:(NSString *)rootDirPath queueDirs:(SFQueueDirs *)queueDirs operationQueue:(NSOperationQueue *)operationQueue config:(NSURLSessionConfiguration *)config;

- (BOOL)upload;

@end
