// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFConfig.h"
#import "SFEventFileManager.h"
#import "SFEventFileUploader.h"

@interface SFEventQueue : NSObject

- (id)initWithIdentifier:(NSString *)identifier config:(SFConfig)config queue:(NSOperationQueue *)queue manager:(SFEventFileManager *)manager uploader:(SFEventFileUploader *)uploader;

- (void)append:(NSDictionary *)event;

@end