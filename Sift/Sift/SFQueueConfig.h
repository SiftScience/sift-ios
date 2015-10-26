// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

typedef struct {
    BOOL appendEventOnlyWhenDifferent;
    NSInteger uploadEventsWhenLargerThan;
    NSTimeInterval uploadEventsWhenOlderThan;
} SFQueueConfig;
