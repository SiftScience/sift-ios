// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SiftTokenBucket.h"

@implementation SiftTokenBucket {
    // Bucket parameters.
    double _numTokens;
    NSTimeInterval _interval;

    // Number of tokens in the bucket.
    double _allowance;

    // Last time we call `tryAcquire` (for refilling the bucket).
    NSTimeInterval _lastAcquire;
}

- (instancetype)initWithNumTokens:(double)numTokens interval:(NSTimeInterval)interval {
    self = [super init];
    if (self) {
        _numTokens = numTokens;
        _interval = interval;

        // Start with a full bucket.
        _allowance = _numTokens;

        _lastAcquire = -1;
    }
    return self;
}

- (BOOL)tryAcquire {
    return [self tryAcquire:1 at:[[NSDate date] timeIntervalSince1970]];
}

- (BOOL)tryAcquire:(double)numAcquired at:(NSTimeInterval)now {
    // Refill the bucket.
    if (_lastAcquire >= 0) {
        NSTimeInterval sinceLastAcquire = now - _lastAcquire;
        if (sinceLastAcquire > 0) {  // Protect us against system clock manipulation.
            _allowance += sinceLastAcquire * _numTokens / _interval;
            if (_allowance > _numTokens) {
                _allowance = _numTokens;  // Throttle.
            }
        }
    }

    _lastAcquire = now;

    // To accomodate floating-point errors when computing allowance.
    if (_allowance - numAcquired > -1e-5) {
        _allowance -= numAcquired;
        return YES;
    } else {
        return NO;
    }
}

#pragma mark - NSCoding

static NSString * const SF_NUM_TOKENS = @"numTokens";
static NSString * const SF_INTERVAL = @"interval";
static NSString * const SF_ALLOWANCE = @"allowance";
static NSString * const SF_LAST_ACQUIRE = @"lastAcquire";

- (instancetype)initWithCoder:(NSCoder *)decoder {
    self = [super init];
    if (self) {
        _numTokens = [decoder decodeDoubleForKey:SF_NUM_TOKENS];
        _interval = [decoder decodeDoubleForKey:SF_INTERVAL];
        _allowance = [decoder decodeDoubleForKey:SF_ALLOWANCE];
        _lastAcquire = [decoder decodeDoubleForKey:SF_LAST_ACQUIRE];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeDouble:_numTokens forKey:SF_NUM_TOKENS];
    [coder encodeDouble:_interval forKey:SF_INTERVAL];
    [coder encodeDouble:_allowance forKey:SF_ALLOWANCE];
    [coder encodeDouble:_lastAcquire forKey:SF_LAST_ACQUIRE];
}

@end
