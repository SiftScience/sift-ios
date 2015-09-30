// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFConfig.h"
#import "SFEventFileManager.h"
#import "SFEventFileUploader.h"

@interface SFEventQueue : NSObject

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFConfig)config queue:(NSOperationQueue *)queue manager:(SFEventFileManager *)manager uploader:(SFEventFileUploader *)uploader;

- (void)append:(NSDictionary *)event withBeaconKey:(NSString *)beaconKey;

@end
