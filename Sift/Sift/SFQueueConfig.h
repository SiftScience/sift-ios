// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

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
     * Specify when the current Record IO file of an `SFQueue` should be
     * rotated.
     */
    NSInteger rotateWhenLargerThan;
    NSTimeInterval rotateWhenOlderThan;
} SFQueueConfig;
