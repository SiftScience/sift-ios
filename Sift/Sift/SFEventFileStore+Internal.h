// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFEventFileStore ()

- (NSFileHandle *)currentEventFile;

- (void)closeCurrentEventFile;

- (NSArray *)eventFilePaths;

- (int)eventFileIndex:(NSString *)eventFileName;

@end
