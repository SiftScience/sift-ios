// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"

@interface Sift : NSObject

+ (instancetype)sharedSift;

- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config;

- (BOOL)removeEventQueue:(NSString *)identifier purge:(BOOL)purge;

- (void)appendEvent:(NSDictionary *)event;

- (void)appendEvent:(NSDictionary *)event toQueue:(NSString *)identifier;

- (BOOL)upload;

@property (nonatomic) NSTimeInterval uploadPeriod;

@property (nonatomic) NSString *serverUrlFormat;

@property (nonatomic) NSString *accountId;

@property (nonatomic) NSString *beaconKey;

@end
