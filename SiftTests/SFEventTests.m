// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFEvent.h"
#import "SFEvent+Private.h"

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

- (void)testListRequest {
    NSArray *events;
    NSDictionary *expect, *actual;

    events = @[];
    expect = @{@"data": @[]};
    actual = [NSJSONSerialization JSONObjectWithData:[SFEvent listRequest:events] options:0 error:nil];
    XCTAssertEqualObjects(expect, actual);

    events = SFBeNice(@[[SFEvent eventWithType:@"some-type" path:@"some-path" fields:nil],
                        [SFEvent eventWithType:nil path:nil fields:@{@"key": @"value"}],
                        [SFEvent eventWithType:nil path:nil fields:@{@1: @"value"}],  // Key is not string typed.
                        [SFEvent eventWithType:nil path:nil fields:@{@"key": @1}]]);  // Value is not string typed.
    expect = @{@"data": @[@{@"time": @0, @"mobile_event_type": @"some-type", @"path": @"some-path", @"user_id": @"some-id"},
                          @{@"time": @0, @"user_id": @"some-id", @"fields": @{@"key": @"value"}}]};
    actual = [NSJSONSerialization JSONObjectWithData:[SFEvent listRequest:events] options:0 error:nil];
    XCTAssertEqualObjects(expect, actual);
}

static NSArray *SFBeNice(NSArray *events) {
    for (SFEvent *event in events) {
        event.userId = @"some-id";
        event.time = 0;
    }
    return events;
}

@end
