// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFTokenBucket.h"

@interface SFTokenBucketTests : XCTestCase

@end

@implementation SFTokenBucketTests

- (void)testTokenBucket {
    SFTokenBucket *bucket;

    bucket = [[SFTokenBucket alloc] initWithNumTokens:1 interval:10];

    XCTAssertTrue([bucket tryAcquire:1 at:1001]);

    XCTAssertFalse([bucket tryAcquire:1 at:1002]);
    XCTAssertFalse([bucket tryAcquire:1 at:1003]);
    XCTAssertFalse([bucket tryAcquire:1 at:1004]);
    XCTAssertFalse([bucket tryAcquire:1 at:1005]);
    XCTAssertFalse([bucket tryAcquire:1 at:1006]);
    XCTAssertFalse([bucket tryAcquire:1 at:1007]);
    XCTAssertFalse([bucket tryAcquire:1 at:1008]);
    XCTAssertFalse([bucket tryAcquire:1 at:1009]);
    XCTAssertFalse([bucket tryAcquire:1 at:1010]);

    XCTAssertTrue([bucket tryAcquire:1 at:1011]);

    bucket = [[SFTokenBucket alloc] initWithNumTokens:2 interval:10];
    XCTAssertTrue( [bucket tryAcquire:1 at:1001]);
    XCTAssertFalse([bucket tryAcquire:2 at:1002]);  // Exceeding allowance!
    XCTAssertTrue( [bucket tryAcquire:1 at:1003]);
    XCTAssertFalse([bucket tryAcquire:1 at:1004]);
}

@end
