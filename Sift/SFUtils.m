// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFUtils.h"

SFTimestamp SFCurrentTime(void) {
    return [[NSDate date] timeIntervalSince1970] * 1000.0;
}
