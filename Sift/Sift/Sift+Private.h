// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

@interface Sift ()

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath operationQueue:(NSOperationQueue *)operationQueue queueDir:(SFQueueDirs *)queueDirs uploader:(SFUploader *)uploader;

- (BOOL)appendEvent:(NSDictionary *)event toQueue:(NSString *)identifier;

- (void)enqueueUpload:(NSTimer *)timer;

@end
