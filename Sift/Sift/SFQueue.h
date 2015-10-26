// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"
#import "SFQueueDirs.h"

@interface SFQueue : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config operationQueue:(NSOperationQueue *)operationQueue queueDirs:(SFQueueDirs *)queueDirs;

- (void)append:(NSDictionary *)event;

- (void)maybeRotateFile;

@end
