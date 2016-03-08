// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFEvent.h"

#import "SFLocation.h"

@interface SFLocationTests : XCTestCase

@end

@implementation SFLocationTests {
}

- (void)testAugmentEvent {
    SFLocation *location = [SFLocation new];

    XCTestExpectation *expectation;
    SFEvent *event;

    expectation = [self expectationWithDescription:@"Wait for augmenting events"];
    event = [SFEvent eventWithType:@"type-1" path:@"path-1" fields:nil];
    [location augment:event onCompletion:^(SFEvent *actual) {
        [expectation fulfill];
        // You didn't authorize location service for unit tests...
        XCTAssertTrue([event isEssentiallyEqualTo:actual]);
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    expectation = [self expectationWithDescription:@"Wait for augmenting events"];
    event = [SFEvent eventWithType:@"type-2" path:@"path-2" fields:@{@"x": @"y"}];
    [location augment:event onCompletion:^(SFEvent *actual) {
        [expectation fulfill];
        // You didn't authorize location service for unit tests...
        XCTAssertTrue([event isEssentiallyEqualTo:actual]);
    }];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

@end
