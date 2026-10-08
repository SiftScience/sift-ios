// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

@import CoreLocation;

#import "SiftDebug.h"

#import "SiftIosAppState.h"
#import "SiftIosAppStateCollector.h"
#import "SiftIosAppStateCollector+Private.h"
#import "SiftUtils.h"
#import "TaskManager.h"
#import "XCTestCase+SiftCollector.h"

// Notification handlers, called directly to avoid posting app-wide notifications.
@interface SiftIosAppStateCollector (Testing)
- (void)viewControllerDidChange:(NSNotification *)notification;
- (void)willEnterForeground;
- (void)didEnterBackground;
@end

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

    // Releasing a collector with a suspended timer source crashes the test process.
    [_iosAppStateCollector resume];
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

#pragma mark - Manual title

- (void)testSetManualTitleDoesNotCollect {
    [self startCapturingAppendedEvents];
    SiftIosAppStateCollector *collector = [self makeQuietCollector];

    [collector setManualTitle:@"QuietScreen"];
    [self drainCollector:collector];

    XCTAssertEqualObjects([collector valueForKey:@"manualLabel"], @"QuietScreen");
    XCTAssertEqual([self capturedEventCountWithTitle:@"QuietScreen"], 0);
}

- (void)testManualTitleIsUsedByLaterCollections {
    [self startCapturingAppendedEvents];
    SiftIosAppStateCollector *collector = [self makeQuietCollector];

    [collector setManualTitle:@"PersistScreen"];
    [collector requestCollectionWithTitle:nil];
    [collector collectWithTitle:nil andTimestamp:SFCurrentTime()];
    [self drainCollector:collector];

    XCTAssertEqual([self capturedEventCountWithTitle:@"PersistScreen"], 2);
}

- (void)testManualTitleSurvivesAutomaticNavigationTitle {
    [self startCapturingAppendedEvents];
    SiftIosAppStateCollector *collector = [self makeQuietCollector];

    [collector setManualTitle:@"ManualScreen"];
    [collector viewControllerDidChange:[self navigationNotificationShowing:[UIViewController new]]];
    [collector requestCollectionWithTitle:nil];
    [self drainCollector:collector];

    XCTAssertEqualObjects([collector valueForKey:@"manualLabel"], @"ManualScreen");
    XCTAssertEqual([self capturedEventCountWithTitle:@"ManualScreen"], 2);
    XCTAssertEqual([self capturedEventCountWithTitle:@"UIViewController"], 0);
}

- (void)testAutomaticNavigationTitleDoesNotPersist {
    [self startCapturingAppendedEvents];
    SiftIosAppStateCollector *collector = [self makeQuietCollector];

    [collector viewControllerDidChange:[self navigationNotificationShowing:[UITabBarController new]]];
    [self drainCollector:collector];
    XCTAssertEqual([self capturedEventCountWithTitle:@"UITabBarController"], 1);

    [collector requestCollectionWithTitle:nil];
    [self drainCollector:collector];
    XCTAssertEqual([self capturedEventCountWithTitle:@"UITabBarController"], 1);
    XCTAssertNil([collector valueForKey:@"manualLabel"]);
}

- (void)testManualTitleInBackground {
    [self startCapturingAppendedEvents];
    SiftIosAppStateCollector *collector = [self makeQuietCollector];

    [collector didEnterBackground];
    NSPredicate *suspended = [NSPredicate predicateWithFormat:@"serialSuspendCounter == 1"];
    [self waitForExpectations:@[[[XCTNSPredicateExpectation alloc] initWithPredicate:suspended object:collector]] timeout:2];

    // The label is recorded right away; a collection requested now waits for the foreground.
    [collector setManualTitle:@"BackgroundScreen"];
    [collector requestCollectionWithTitle:nil];
    [self flushMainQueue];
    XCTAssertEqualObjects([collector valueForKey:@"manualLabel"], @"BackgroundScreen");
    XCTAssertEqual([self capturedEventCountWithTitle:@"BackgroundScreen"], 0);

    [collector willEnterForeground];
    [self drainCollector:collector];
    XCTAssertEqual([self capturedEventCountWithTitle:@"BackgroundScreen"], 1);
}

- (void)testNilResetsManualTitle {
    [self startCapturingAppendedEvents];
    SiftIosAppStateCollector *collector = [self makeQuietCollector];

    [collector setManualTitle:@"ResetScreen"];
    [collector setManualTitle:nil];
    [collector viewControllerDidChange:[self navigationNotificationShowing:[UIViewController new]]];
    [self drainCollector:collector];

    XCTAssertNil([collector valueForKey:@"manualLabel"]);
    XCTAssertEqual([self capturedEventCountWithTitle:@"ResetScreen"], 0);
    XCTAssertEqual([self capturedEventCountWithTitle:@"UIViewController"], 1);
}

- (void)testManualTitleEmptyOrNonStringResets {
    SiftIosAppStateCollector *collector = [self makeQuietCollector];

    NSMutableString *title = [NSMutableString stringWithString:@"CopiedScreen"];
    [collector setManualTitle:title];
    [title setString:@"Mutated"];
    XCTAssertEqualObjects([collector valueForKey:@"manualLabel"], @"CopiedScreen");

    [collector setManualTitle:@""];
    XCTAssertNil([collector valueForKey:@"manualLabel"]);

    [collector setManualTitle:@"CopiedScreen"];
    [collector setManualTitle:(NSString *)[NSNull null]];
    XCTAssertNil([collector valueForKey:@"manualLabel"]);
}

- (NSNotification *)navigationNotificationShowing:(UIViewController *)viewController {
    return [NSNotification notificationWithName:@"UINavigationControllerDidShowViewControllerNotification"
                                         object:nil
                                       userInfo:@{@"UINavigationControllerNextVisibleViewController": viewController}];
}

@end
