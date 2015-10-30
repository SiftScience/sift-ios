// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFQueueConfig.h"

@interface Sift : NSObject

+ (instancetype)sharedSift;

- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config;

- (BOOL)removeEventQueue:(NSString *)identifier purge:(BOOL)purge;

- (BOOL)appendEvent:(NSString *)path mobileEventType:(NSString *)mobileEventType userId:(NSString *)userId fields:(NSDictionary *)fields;

- (BOOL)appendEvent:(NSString *)path mobileEventType:(NSString *)mobileEventType userId:(NSString *)userId fields:(NSDictionary *)fields toQueue:(NSString *)identifier;

- (BOOL)upload;

@property (nonatomic) NSTimeInterval uploadPeriod;

@property NSString *serverUrlFormat;

@property NSString *accountId;

@property NSString *beaconKey;

@property NSString *userId;

@end
