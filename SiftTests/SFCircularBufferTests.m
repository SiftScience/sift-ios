// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFCircularBuffer.h"

@interface SFCircularBufferTests : XCTestCase

@end

@implementation SFCircularBufferTests

- (void)testCircularBuffer {
    SFCircularBuffer<NSNumber *> *buffer;
    NSArray<NSNumber *> *data;

    buffer = [[SFCircularBuffer alloc] initWithSize:1];
    XCTAssertEqual(1, buffer.size);
    XCTAssertEqual(0, buffer.count);
    XCTAssertNil(buffer.firstObject);
    XCTAssertNil(buffer.lastObject);
    XCTAssertEqualObjects(@[], [buffer shallowCopy]);

    XCTAssertNil([buffer append:@99]);
    XCTAssertEqual(1, buffer.size);
    XCTAssertEqual(1, buffer.count);
    XCTAssertEqualObjects(@99, buffer.firstObject);
    XCTAssertEqualObjects(@99, buffer.lastObject);
    XCTAssertEqualObjects(@[@99], [buffer shallowCopy]);

    XCTAssertEqualObjects(@99, [buffer append:@100]);
    XCTAssertEqual(1, buffer.size);
    XCTAssertEqual(1, buffer.count);
    XCTAssertEqualObjects(@100, buffer.firstObject);
    XCTAssertEqualObjects(@100, buffer.lastObject);
    XCTAssertEqualObjects(@[@100], [buffer shallowCopy]);

    buffer = [[SFCircularBuffer alloc] initWithSize:2];
    XCTAssertEqual(2, buffer.size);
    XCTAssertEqual(0, buffer.count);
    XCTAssertNil(buffer.firstObject);
    XCTAssertNil(buffer.lastObject);

    XCTAssertNil([buffer append:@99]);
    XCTAssertEqual(2, buffer.size);
    XCTAssertEqual(1, buffer.count);
    XCTAssertEqualObjects(@99, buffer.firstObject);
    XCTAssertEqualObjects(@99, buffer.lastObject);
    XCTAssertEqualObjects(@[@99], [buffer shallowCopy]);

    XCTAssertNil([buffer append:@100]);
    XCTAssertEqual(2, buffer.size);
    XCTAssertEqual(2, buffer.count);
    XCTAssertEqualObjects(@99, buffer.firstObject);
    XCTAssertEqualObjects(@100, buffer.lastObject);
    data = @[@99, @100];
    XCTAssertEqualObjects(data, [buffer shallowCopy]);

    XCTAssertEqualObjects(@99, [buffer append:@101]);
    XCTAssertEqual(2, buffer.size);
    XCTAssertEqual(2, buffer.count);
    XCTAssertEqualObjects(@100, buffer.firstObject);
    XCTAssertEqualObjects(@101, buffer.lastObject);
    data = @[@100, @101];
    XCTAssertEqualObjects(data, [buffer shallowCopy]);

    XCTAssertEqualObjects(@100, [buffer append:@102]);
    XCTAssertEqual(2, buffer.size);
    XCTAssertEqual(2, buffer.count);
    XCTAssertEqualObjects(@101, buffer.firstObject);
    XCTAssertEqualObjects(@102, buffer.lastObject);
    data = @[@101, @102];
    XCTAssertEqualObjects(data, [buffer shallowCopy]);
}

@end
