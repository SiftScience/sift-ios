// Copyright (c) 2016 Sift Science. All rights reserved.

// This is a public header.

#import <Foundation/Foundation.h>

/** Control the behavior of an `SFQueue`. */
typedef struct {
    /**
     * When `acceptSameEventAfter` is set to a nonzero value, the queue will
     * accept the same event again after this number of seconds
     */
    NSTimeInterval acceptSameEventAfter;

    /**
     * The following criteria are combined by "or", meaning if one of
     * them is met, the events of the queue will be uploaded.
     */

    /** Upload events if there are more events than this. */
    NSInteger uploadWhenMoreThan;

    /** Upload events when the last upload time is older than this number of seconds. */
    NSTimeInterval uploadWhenOlderThan;
} SiftQueueConfig;
