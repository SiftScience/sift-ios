// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFConfig.h"

@interface Sift : NSObject

+ (void)configureSharedInstance:(NSString *)beaconKey;

// Useful for testing/integration.
+ (void)configureSharedInstance:(NSString *)beaconKey serverUrl:(NSString *)serverUrl;

+ (Sift *)sharedInstance;

- (BOOL)addEventQueue:(NSString *)identifier config:(SFConfig)config;

- (BOOL)removeEventQueue:(NSString *)identifier purge:(BOOL)purge;

- (void)event:(NSDictionary *)event usingEventQueue:(NSString *)identifier;

// Use the default event queue.
- (void)event:(NSDictionary *)event;

@end
