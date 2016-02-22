// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFDebug.h"
#import "SFUtils.h"

#import "SFRecordIo.h"

@interface SFRecordIoTests : XCTestCase

@end

@implementation SFRecordIoTests {
    NSString *_testFilePath;
}

- (void)setUp {
    [super setUp];
    _testFilePath = [SFCacheDirPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)]];
    [[NSFileManager defaultManager] createFileAtPath:_testFilePath contents:nil attributes:nil];
}

- (void)tearDown {
    NSError *error;
    if (![[NSFileManager defaultManager] removeItemAtPath:_testFilePath error:&error]) {
        SF_DEBUG(@"Could not remove \"%@\" due to %@", _testFilePath, [error localizedDescription]);
    }
    [super tearDown];
}

- (void)testAppendAndRead {
    NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:_testFilePath];
    XCTAssertNotNil(writeHandle);

    NSFileHandle *readHandle = [NSFileHandle fileHandleForReadingAtPath:_testFilePath];
    XCTAssertNotNil(readHandle);

    XCTAssertNil(SFRecordIoReadLastRecord(readHandle));

    NSDictionary *records[] = {
        @{@"key1": @"value1"},
        @{@"key2": @"value2"},
        @{@"key3": @"value3"},
    };

    for (int i = 0; i < sizeof(records) / sizeof(records[0]); i++) {
        XCTAssert(SFRecordIoAppendRecord(writeHandle, records[i]));
        XCTAssert([records[i] isEqualToDictionary:SFRecordIoReadLastRecord(readHandle)]);
    }

    [readHandle seekToFileOffset:0];
    for (int i = 0; i < sizeof(records) / sizeof(records[0]); i++) {
        NSDictionary *record = SFRecordIoReadRecord(readHandle);
        XCTAssert([records[i] isEqualToDictionary:record]);
    }
    XCTAssertNil(SFRecordIoReadRecord(readHandle));  // We've read them all.
}

@end
