// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

typedef struct {
    BOOL appendEventOnlyWhenDifferent;
    unsigned long long uploadEventsWhenLargerThan;
    NSTimeInterval uploadEventsWhenOlderThan;
} SFQueueConfig;
