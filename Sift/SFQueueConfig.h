// Copyright (c) 2016 Sift Science. All rights reserved.

// This is a public header.

#import <Foundation/Foundation.h>

/** Control the behavior of an `SFQueue`. */
typedef struct {
    /**
     * Instruct an `SFQueue` to append an event only when that event is
     * different from the last event of the queue.  This is uesful if
     * you expect events rarely changed.
     *
     * Note that to guarantee the event receiving order on the server,
     * we will be conservative on batching events of queues with this
     * option enabled, and thus event-upload-timeliness would be worse
     * than queues without this option enabled.  So you should not set
     * this option unless you fully understand the trade-offs.
     */
    BOOL appendEventOnlyWhenDifferent;

    /**
     * When `appendEventOnlyWhenDifferent` is `YES`, the queue will
     * accept the same event again after this amount of time.
     *
     * Setting this to 0 is treated as infinite.
     */
    NSTimeInterval acceptSameEventAfter;

    /**
     * The following criteria are combined by "or", meaning if one of
     * them is met, the events of the queue will be uploaded.
     */

    /** Upload events if there are more events than this. */
    NSInteger uploadWhenMoreThan;

    /** Upload events when the last event is older than this. */
    NSTimeInterval uploadWhenOlderThan;
} SFQueueConfig;
