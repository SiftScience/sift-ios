// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileManager.h"
#import "SFEventFileUploader.h"

@interface Sift ()

- (id)initWithRootDirPath:(NSString *)rootDirPath;

@end


@interface Sift (Testing)

@property (nonatomic) NSOperationQueue *operationQueue;

@property (nonatomic) SFEventFileManager *manager;

@property (nonatomic) SFEventFileUploader *uploader;

@end
