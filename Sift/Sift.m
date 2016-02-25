// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFQueue.h"
#import "SFQueueConfig.h"
#import "SFUtils.h"

#import "Sift.h"

static NSString * const SFServerUrlFormat = @"https://api3.siftscience.com/v3/accounts/%@/mobile_events";

static NSString * const SFDefaultEventQueueIdentifier = @"sift-default";

// TODO(clchiou): Experiment a sensible config for the default event queue.
static const SFQueueConfig SFDefaultEventQueueConfig = {
    .appendEventOnlyWhenDifferent = NO,
    .uploadWhenMoreThan = 512,  // Unit: number of events.
    .uploadWhenOlderThan = 60,  // 1 minute.
};

@implementation Sift {
    NSMutableDictionary *_eventQueues;
}

+ (instancetype)sharedInstance {
    static Sift *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [Sift new];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _serverUrlFormat = SFServerUrlFormat;
        _accountId = nil;
        _beaconKey = nil;
        _userId = nil;

        _eventQueues = [NSMutableDictionary new];

        // Create the default event queue.
        if (![self addEventQueue:SFDefaultEventQueueIdentifier config:SFDefaultEventQueueConfig]) {
            self = nil;
            return nil;
        }
    }
    return self;
}

- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config {
    @synchronized(_eventQueues) {
        if ([_eventQueues objectForKey:identifier]) {
            SF_DEBUG(@"Could not overwrite event queue for identifier \"%@\"", identifier);
            return NO;
        }
        SFQueue *queue = [[SFQueue alloc] initWithIdentifier:identifier config:config];
        if (!queue) {
            SF_DEBUG(@"Could not create SFEventQueue for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues setObject:queue forKey:identifier];
        return YES;
    }
}

- (BOOL)removeEventQueue:(NSString *)identifier {
    @synchronized(_eventQueues) {
        if (![_eventQueues objectForKey:identifier]) {
            SF_DEBUG(@"Could not find event queue to be removed for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues removeObjectForKey:identifier];
        return YES;
    }
}

- (BOOL)appendEvent:(SFEvent *)event {
    return [self appendEvent:event toQueue:SFDefaultEventQueueIdentifier];
}

- (BOOL)appendEvent:(SFEvent *)event toQueue:(NSString *)identifier {
    @synchronized(_eventQueues) {
        SFQueue *queue = [_eventQueues objectForKey:identifier];
        if (!queue) {
            SF_DEBUG(@"Could not find event queue for identifier \"%@\" and will drop event", identifier);
            return NO;
        }
        // Record user ID when receiving the event, not when uploading the event.
        if (!event.userId.length) {
            if (!_userId.length) {
                SF_DEBUG(@"event.userId is not optional");
                return NO;
            }
            SF_DEBUG(@"The event's userId is empty; use Sift object's userId: \"%@\"", _userId);
            event.userId = _userId;
        }
        [queue append:event];
        return YES;
    }
}

- (BOOL)upload {
    return NO;  // TODO(clchiou): Implement this.
}

@end
