// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

NSInteger SFTimestampMillis(void);

NSString *SFCacheDirPath(void);

BOOL SFTouchFilePath(NSString *path);

id SFReadJsonFromFile(NSString *filePath);

BOOL SFWriteJsonToFile(id object, NSString *filePath);