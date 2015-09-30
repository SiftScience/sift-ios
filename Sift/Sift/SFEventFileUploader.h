// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileManager.h"

@interface SFEventFileUploader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (instancetype)initWithQueue:(NSOperationQueue *)queue
            manager:(SFEventFileManager *)manager
        rootDirPath:(NSString *)rootDirPath
          serverUrl:(NSString *)serverUrl;

- (void)upload:(NSString *)identifier path:(NSString *)path;

@end
