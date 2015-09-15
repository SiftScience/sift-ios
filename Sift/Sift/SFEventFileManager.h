// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileStore.h"

@interface SFEventFileManager : NSObject

- (id)initWithRootDir:(NSString *)rootDirPath;

- (BOOL)addEventStore:(NSString *)identifier;

- (BOOL)removeEventStore:(NSString *)identifier;

- (BOOL)accessEventStore:(NSString *)identifier block:(BOOL (^)(SFEventFileStore *store))block;

- (void)removeRootDir;

@end
