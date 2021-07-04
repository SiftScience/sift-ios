//
//  TaskManager.h
//  Sift
//
//  Created by George Kuriakose on 01/07/21.
//  Copyright © 2021 Sift Science. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^ Runner)(void);

@interface TaskManager : NSObject

- (void)submitWithTask:(Runner)task queue:(dispatch_queue_t)queue;

- (void)scheduleWithTask:(Runner)task queue:(dispatch_queue_t)queue delay:(int64_t)delay;

@end
