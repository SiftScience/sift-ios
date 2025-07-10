// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

@import CoreLocation;

#import "SiftDebug.h"

#import "SiftIosAppState.h"
#import "SiftIosAppStateCollector.h"
#import "SiftIosAppStateCollector+Private.h"
#import "TaskManager.h"

@interface SiftIosAppStateTests : XCTestCase

@end

@implementation SiftIosAppStateTests

- (void)testCollect {
    NSDictionary *actual = SFCollectIosAppState([CLLocationManager new], nil);
    SF_DEBUG(@"Collect app state: %@", actual);
    XCTAssertNotNil(actual);
}

- (void)testCLLocationToDictionary {
    NSDictionary *dict = SFCLLocationToDictionary([CLLocationManager new].location);
    SF_DEBUG(@"CLLocation To Dictionary: %@", dict);
    XCTAssertNotNil(dict);
    
}

- (void)testIOSAppLifeCycle {
    SiftIosAppStateCollector *_iosAppStateCollector = [[SiftIosAppStateCollector alloc] initWithArchivePath: @"test_app_state_collector"];
    XCTAssertEqual([_iosAppStateCollector serialSuspendCounter], 0);
    
    // When app enter background
    [[NSNotificationCenter defaultCenter] postNotificationName: UIApplicationDidEnterBackgroundNotification object:nil userInfo:nil];
    // Sleep for 1.5 seconds.
    [NSThread sleepForTimeInterval:1.5];
    XCTAssertEqual([_iosAppStateCollector serialSuspendCounter], 1);
    
    // When app enter foreground
    [[NSNotificationCenter defaultCenter] postNotificationName: UIApplicationWillEnterForegroundNotification object:nil userInfo:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName: UIApplicationDidBecomeActiveNotification object:nil userInfo:nil];

    XCTAssertEqual([_iosAppStateCollector serialSuspendCounter], 0);
}

- (void)testViewDidChange {
    [[NSNotificationCenter defaultCenter] postNotificationName: @"UINavigationControllerDidShowViewControllerNotification" object:nil userInfo:nil];
}

- (void)testPause {
    SiftIosAppStateCollector *_iosAppStateCollector = [[SiftIosAppStateCollector alloc] initWithArchivePath: @"test_app_state_collector"];
    TaskManager *taskManager = [_iosAppStateCollector valueForKey:@"_taskManager"];
    dispatch_queue_t serial = [_iosAppStateCollector valueForKey:@"_serial"];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    expectation.inverted = YES;
    
    dispatch_source_t timer = [_iosAppStateCollector valueForKey:@"_source"];
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 100, NSEC_PER_SEC);

    [_iosAppStateCollector pause];
    XCTAssertTrue([[_iosAppStateCollector valueForKey:@"_isPaused"] boolValue]);
    
    // resetting '_lastCollectedAt' to make sure that we don't collect events after pause
    [taskManager submitWithTask:^{
        [taskManager submitWithTask:^{
            [taskManager submitWithTask:^{
                [taskManager submitWithTask:^{
                    [_iosAppStateCollector setValue:@1 forKey:@"_lastCollectedAt"];
                } queue:serial];
            } queue:dispatch_get_main_queue()];
        } queue:serial];
    } queue:dispatch_get_main_queue()];
    
    [self waitForExpectationsWithTimeout:1.5 handler:nil];
    
    uint64_t lastCollectedAt = [[_iosAppStateCollector valueForKey:@"_lastCollectedAt"] unsignedLongLongValue];
    XCTAssertEqual(lastCollectedAt, 1);
    
    // Test that multiple pause calls don't cause issues
    [_iosAppStateCollector pause];
    XCTAssertTrue([[_iosAppStateCollector valueForKey:@"_isPaused"] boolValue]);
}

- (void)testResume {
    SiftIosAppStateCollector *_iosAppStateCollector = [[SiftIosAppStateCollector alloc] initWithArchivePath: @"test_app_state_collector"];
    
    [_iosAppStateCollector pause];
    XCTAssertTrue([[_iosAppStateCollector valueForKey:@"_isPaused"] boolValue]);
    
    [_iosAppStateCollector resume];
    XCTAssertFalse([[_iosAppStateCollector valueForKey:@"_isPaused"] boolValue]);
    
    // Test that multiple resume calls don't cause issues
    [_iosAppStateCollector resume];
    XCTAssertFalse([[_iosAppStateCollector valueForKey:@"_isPaused"] boolValue]);
}

@end
