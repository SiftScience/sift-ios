// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

@import CoreLocation;

#import "SiftDebug.h"

#import "SiftIosAppState.h"
#import "SiftIosAppStateCollector.h"
#import "SiftIosAppStateCollector+Private.h"

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

@end
