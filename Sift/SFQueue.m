// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFUtils.h"

#import "SFQueue.h"

@implementation SFQueue {
    NSString *_identifier;
    NSMutableArray *_queue;
    SFQueueConfig _config;
    SFEvent *_lastEvent;
    SFTimestamp _lastEventTimestamp;
}

- (instancetype)initWithIdentifier:(NSString *)identifier config:(SFQueueConfig)config {
    self = [super init];
    if (self) {
        _identifier = identifier;
        _config = config;
        _queue = [NSMutableArray new];
        _lastEvent = nil;
        _lastEventTimestamp = 0;
    }
    return self;
}

- (void)append:(SFEvent *)event {
    @synchronized(self) {
        if (!event) {
            return;  // Don't append nil.
        }
        if (_config.appendEventOnlyWhenDifferent && _lastEvent && [_lastEvent isEssentiallyEqualTo:event]) {
            return;  // Drop the same event as configured.
        }
        [_queue addObject:event];
        _lastEvent = event;
        _lastEventTimestamp = SFCurrentTime();
    }
}

- (NSArray *)transfer {
    @synchronized(self) {
        NSArray *queue = _queue;
        _queue = [NSMutableArray new];
        return queue;
    }
}

@end
