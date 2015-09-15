// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFUtil.h"

#import "SFEventFile.h"
#import "SFEventFile+Internal.h"

@interface SFEventFileTests : XCTestCase

@end

@implementation SFEventFileTests {
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
        NSLog(@"Could not remove \"%@\" due to %@", _testFilePath, [error localizedDescription]);
    }
    [super tearDown];
}

- (void)testAppendAndRead {
    NSFileHandle *writeHandle = [NSFileHandle fileHandleForWritingAtPath:_testFilePath];
    XCTAssertNotNil(writeHandle);
    
    NSFileHandle *readHandle = [NSFileHandle fileHandleForReadingAtPath:_testFilePath];
    XCTAssertNotNil(readHandle);

    XCTAssertNil(SFEventFileReadLastEvent(readHandle));

    NSDictionary *events[] = {
        @{@"key1": @"value1"},
        @{@"key2": @"value2"},
        @{@"key3": @"value3"},
    };

    for (int i = 0; i < sizeof(events) / sizeof(events[0]); i++) {
        XCTAssert(SFEventFileAppendEvent(writeHandle, events[i]));
        XCTAssert([events[i] isEqualToDictionary:SFEventFileReadLastEvent(readHandle)]);
    }

    [readHandle seekToFileOffset:0];
    NSData *data = [readHandle readDataToEndOfFile];
    NSUInteger location = 0;
    for (int i = 0; i < sizeof(events) / sizeof(events[0]); i++) {
        NSDictionary *event = SFEventFileReadEventData(data, &location);
        XCTAssert([events[i] isEqualToDictionary:event]);
    }
    XCTAssertEqual(data.length, location);  // We have read all data.
}

@end
