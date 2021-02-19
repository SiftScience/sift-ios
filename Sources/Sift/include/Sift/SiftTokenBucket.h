// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

@interface SiftTokenBucket : NSObject <NSCoding>

/** Create a token bucket that you may acquire at most `numToken` within `interval` of time. */
- (instancetype)initWithNumTokens:(double)numTokens interval:(NSTimeInterval)interval;

/** Try to acquire one token and return YES on success (non-blocking). */
- (BOOL)tryAcquire;

/* Same as above but for testing. */
- (BOOL)tryAcquire:(double)numAcquired at:(NSTimeInterval)now;

@end
