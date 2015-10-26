// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFRotatedFiles.h"

@interface SFQueueDirs : NSObject

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath;

- (BOOL)addDir:(NSString *)identifier;

- (BOOL)removeDir:(NSString *)identifier purge:(BOOL)purge;

- (BOOL)useDir:(NSString *)identifier withBlock:(BOOL (^)(SFRotatedFiles *rotatedFiles))block;

- (BOOL)useDirsWithBlock:(BOOL (^)(SFRotatedFiles *rotatedFiles))block;

- (void)removeRootDir;

@property (readonly) NSInteger numDirs;

@end
