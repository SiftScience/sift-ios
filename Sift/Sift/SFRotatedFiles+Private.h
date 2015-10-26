// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFRotatedFiles ()

- (NSFileHandle *)currentFile;

- (void)closeCurrentFile;

- (NSArray *)filePaths;

- (int)fileIndex:(NSString *)fileName;

@end
