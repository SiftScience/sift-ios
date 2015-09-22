// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileStore.h"

@interface SFEventFileManager : NSObject

- (id)initWithRootDir:(NSString *)rootDirPath;

- (BOOL)addEventStore:(NSString *)identifier;

- (BOOL)removeEventStore:(NSString *)identifier purge:(BOOL)purge;

- (BOOL)useEventStore:(NSString *)identifier withBlock:(BOOL (^)(SFEventFileStore *store))block;

- (void)removeRootDir;

@end
