// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFEvent.h"

@interface SFEventTests : XCTestCase

@end

@implementation SFEventTests

- (void)testEvent {
    SFEvent *event = [SFEvent eventWithType:@"type" path:@"path" fields:@{@"key": @"value"}];
    XCTAssertNotNil(event);

    XCTAssertGreaterThan(event.time, 0);
    XCTAssertEqualObjects(event.type, @"type");
    XCTAssertEqualObjects(event.path, @"path");
    XCTAssertEqualObjects(event.fields, @{@"key": @"value"});
    XCTAssertNil(event.userId);
    XCTAssertNil(event.deviceProperties);
    XCTAssertNil(event.metrics);

    XCTAssertTrue([event isEssentiallyEqualTo:event]);
    XCTAssertFalse([event isEssentiallyEqualTo:nil]);
}

- (void)testCoder {
    SFEvent *expect = [SFEvent eventWithType:@"type" path:@"path" fields:@{@"key": @"value"}];
    XCTAssertNotNil(expect);

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:expect];
    SFEvent *actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertTrue([expect isEssentiallyEqualTo:actual]);
    XCTAssertEqual(actual.time, expect.time);
}

@end
