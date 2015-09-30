// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileManager.h"
#import "SFEventFileUploader.h"

@interface Sift ()

- (instancetype)initWithBeaconKey:(NSString *)beaconKey serverUrl:(NSString *)serverUrl rootDirPath:(NSString *)rootDirPath;

@end


@interface Sift (Testing)

@property (nonatomic) NSOperationQueue *operationQueue;

@property (nonatomic) SFEventFileManager *manager;

@property (nonatomic) SFEventFileUploader *uploader;

@end
