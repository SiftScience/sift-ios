// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileManager.h"

@interface SFEventFileUploader : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

- (id)initWithQueue:(NSOperationQueue *)queue manager:(SFEventFileManager *)manager rootDirPath:(NSString *)rootDirPath;

- (void)upload:(NSString *)path identifier:(NSString *)identifier;

@end