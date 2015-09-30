// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileStore.h"

@interface SFEventFileManager : NSObject

- (instancetype)initWithRootDir:(NSString *)rootDirPath;

- (BOOL)addEventStore:(NSString *)identifier;

- (BOOL)removeEventStore:(NSString *)identifier purge:(BOOL)purge;

- (BOOL)useEventStore:(NSString *)identifier withBlock:(BOOL (^)(SFEventFileStore *store))block;

- (void)removeRootDir;

@property (readonly) NSInteger numEventStores;

@end
