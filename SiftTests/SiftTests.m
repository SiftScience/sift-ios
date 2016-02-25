// Copyright (c) 2015 Sift Science. All rights reserved.

@import XCTest;

#import "Sift.h"

@interface SiftTests : XCTestCase

@end

@implementation SiftTests

- (void)testAppendEvent {
    Sift *sift = [Sift new];

    XCTAssertFalse([sift appendEvent:[SFEvent eventWithType:nil path:nil fields:nil]]);

    sift.userId = @"1234";
    XCTAssertTrue([sift appendEvent:[SFEvent eventWithType:nil path:nil fields:nil]]);
}

@end
