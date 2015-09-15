// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileManager.h"
#import "SFEventFileUploader.h"

SFEventFileUploader *SFStubHttpProtocolMakeUploader(NSOperationQueue *queue, SFEventFileManager *manager, NSString *rootDirPath);