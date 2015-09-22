// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFConfig.h"

@interface Sift : NSObject

+ (Sift *)sharedInstance;

- (BOOL)addEventQueue:(NSString *)identifier config:(SFConfig)config;

- (BOOL)removeEventQueue:(NSString *)identifier purge:(BOOL)purge;

- (void)event:(NSDictionary *)event usingEventQueue:(NSString *)identifier;

// Use the default event queue.
- (void)event:(NSDictionary *)event;

@end
