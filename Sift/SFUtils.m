// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFUtils.h"

SFTimestamp SFCurrentTime(void) {
    return [[NSDate date] timeIntervalSince1970] * 1000.0;
}

NSString *SFDoubleToString(double value) {
    return [NSNumber numberWithDouble:value].stringValue;
}

NSString *SFCacheDirPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}
