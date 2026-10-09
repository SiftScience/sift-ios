//
//  XCTestCase+SiftCollector.m
//  SiftTests
//
//  Copyright © 2026 Sift Science. All rights reserved.
//

#import <objc/runtime.h>

#import "SiftUtils.h"

#import "Sift.h"
#import "SiftIosAppStateCollector+Private.h"
#import "TaskManager.h"
#import "XCTestCase+SiftCollector.h"
#import "XCTestCase+Swizzling.h"

// Allocated once so its identity (also the lock) never changes between tests.
static NSMutableArray<SiftEvent *> *capturedAppendedEvents;

static NSArray<SiftEvent *> *CapturedEventsSnapshot(void) {
    @synchronized (capturedAppendedEvents) {
        return [capturedAppendedEvents copy];
    }
}

@implementation Sift (SiftCollectorTesting)

- (BOOL)sift_test_captureAppendEvent:(SiftEvent *)event {
    @synchronized (capturedAppendedEvents) {
        [capturedAppendedEvents addObject:event];
    }
    return YES;
}

@end

@implementation XCTestCase (SiftCollector)

- (SiftIosAppStateCollector *)makeQuietCollector {
    NSString *archiveName = [NSString stringWithFormat:@"test_app_state_collector-%07d", arc4random_uniform(1 << 20)];
    NSString *archivePath = [SFCacheDirPath() stringByAppendingPathComponent:archiveName];
    [self addTeardownBlock:^{
        [[NSFileManager defaultManager] removeItemAtPath:archivePath error:nil];
    }];
    SiftIosAppStateCollector *collector = [[SiftIosAppStateCollector alloc] initWithArchivePath:archivePath];
    // Written on _serial, like the collector's own unarchive. The periodic check reads
    // _lastCollectedAt only after a main-queue hop, i.e. after this returns.
    dispatch_sync([collector valueForKey:@"_serial"], ^{
        [collector setValue:@(SFCurrentTime()) forKey:@"_lastCollectedAt"];
    });
    return collector;
}

- (void)startCapturingAppendedEvents {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        capturedAppendedEvents = [NSMutableArray new];
    });
    @synchronized (capturedAppendedEvents) {
        [capturedAppendedEvents removeAllObjects];
    }
    Method original = class_getInstanceMethod(Sift.class, @selector(appendEvent:));
    Method capture = class_getInstanceMethod(Sift.class, @selector(sift_test_captureAppendEvent:));
    [self swizzleMethod:original withMethod:capture];
    [self addTeardownBlock:^{
        [self swizzleMethod:original withMethod:capture];
    }];
}

- (NSUInteger)capturedEventCountWithTitle:(NSString *)title {
    NSUInteger count = 0;
    for (SiftEvent *event in CapturedEventsSnapshot()) {
        if ([event.iosAppState[@"window_root_view_controller_titles"] isEqual:@[title]]) {
            count++;
        }
    }
    return count;
}

- (void)flushMainQueue {
    XCTestExpectation *expectation = [self expectationWithDescription:@"main queue flushed"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [expectation fulfill];
    });
    [self waitForExpectations:@[expectation] timeout:1.5];
}

// Longer than the collector's SF_HEADING_INTERVAL (4 s), the delay before a
// foreground collection appends its event, plus a margin.
static const int64_t SFTestAppendWait = 4500 * NSEC_PER_MSEC;

- (void)drainCollector:(SiftIosAppStateCollector *)collector {
    // A collection runs the hops requestCollectionWithTitle: (_serial) ->
    // collectWithTitle: (main, then _serial), and the last hop schedules the append
    // SF_HEADING_INTERVAL later on _serial. Queue the same hops, then wait longer.
    TaskManager *taskManager = [collector valueForKey:@"_taskManager"];
    dispatch_queue_t serial = [collector valueForKey:@"_serial"];
    XCTestExpectation *expectation = [self expectationWithDescription:@"collections appended"];
    [taskManager submitWithTask:^{
        [taskManager submitWithTask:^{
            [taskManager scheduleWithTask:^{
                [expectation fulfill];
            } queue:serial delay:SFTestAppendWait];
        } queue:dispatch_get_main_queue()];
    } queue:serial];
    [self waitForExpectations:@[expectation] timeout:8];
}

@end
