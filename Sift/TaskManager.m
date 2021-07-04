//
//  TaskManager.m
//  Sift
//
//  Created by George Kuriakose on 01/07/21.
//  Copyright © 2021 Sift Science. All rights reserved.
//

#import "TaskManager.h"

@implementation TaskManager

- (void)submitWithTask:(Runner)task queue:(dispatch_queue_t)queue {
    dispatch_async(queue, task);
}

- (void)scheduleWithTask:(Runner)task queue:(dispatch_queue_t)queue delay:(int64_t)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), queue, task);
}

@end
