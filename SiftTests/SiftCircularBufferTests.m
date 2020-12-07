// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftCompatibility.h"

#import "SiftCircularBuffer.h"

@interface SiftCircularBufferTests : XCTestCase

@end

@implementation SiftCircularBufferTests

- (void)testCircularBuffer {
    SF_GENERICS(SiftCircularBuffer, NSNumber *) *buffer;
    SF_GENERICS(NSArray, NSNumber *) *data;

    buffer = [[SiftCircularBuffer alloc] initWithSize:1];
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

    buffer = [[SiftCircularBuffer alloc] initWithSize:2];
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

- (void)testRemoveCircularBufferAllObjects {
    SF_GENERICS(SiftCircularBuffer, NSNumber *) *buffer;

    buffer = [[SiftCircularBuffer alloc] initWithSize:1];
    XCTAssertEqual(1, buffer.size);
    XCTAssertEqual(0, buffer.count);
    XCTAssertNil(buffer.firstObject);
    XCTAssertNil(buffer.lastObject);
    XCTAssertEqualObjects(@[], [buffer shallowCopy]);

    XCTAssertNil([buffer append:nil]);
    XCTAssertNil([buffer append:@100]);
    XCTAssertEqual(1, buffer.size);
    XCTAssertEqual(1, buffer.count);
    XCTAssertEqualObjects(@100, buffer.firstObject);
    XCTAssertEqualObjects(@100, buffer.lastObject);
    XCTAssertEqualObjects(@[@100], [buffer shallowCopy]);
    
    [buffer removeAllObjects];
    XCTAssertEqual(0, buffer.count);
    XCTAssertNil(buffer.firstObject);
    XCTAssertNil(buffer.lastObject);
    XCTAssertEqualObjects(@[], [buffer shallowCopy]);
}

@end
