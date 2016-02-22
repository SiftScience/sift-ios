// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFDebug.h"
#import "SFRecordIo.h"
#import "SFUtils.h"

#import "SFEvent.h"
#import "SFEvent+Utils.h"

@interface SFEventTests : XCTestCase

@end

@implementation SFEventTests {
    NSFileManager *_manager;
    NSString *_dirPath;
}

- (void)setUp {
    [super setUp];
    NSString *dirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _dirPath = [SFCacheDirPath() stringByAppendingPathComponent:dirName];
    _manager = [NSFileManager defaultManager];
    XCTAssert([_manager createDirectoryAtPath:_dirPath withIntermediateDirectories:YES attributes:nil error:nil]);
}

- (void)tearDown {
    NSError *error;
    if (![[NSFileManager defaultManager] removeItemAtPath:_dirPath error:&error]) {
        SF_DEBUG(@"Could not remote \"%@\" due to %@", _dirPath, [error localizedDescription]);
    }
    [super tearDown];
}

- (void)testSFWriteListRequest {
    NSString *filePath = [_dirPath stringByAppendingPathComponent:@"file.json"];
    XCTAssert([_manager createFileAtPath:filePath contents:nil attributes:0]);

    NSString *tmpPath = [_dirPath stringByAppendingPathComponent:@"tmp"];
    XCTAssert([_manager createFileAtPath:tmpPath contents:nil attributes:0]);

    NSDictionary *testdata[] = {
        @{@"key1": @"value1"},
        @{@"key2": @"value2"},
        @{@"key3": @"value3"},
        [[SFEvent eventWithPath:@"path" mobileEventType:@"event_type" userId:@"user_id" fields:@{@"key4": @"value4"}] makeEvent],
    };

    [self writeEvents:@[] fromPath:tmpPath toPath:filePath];
    XCTAssertTrue([[self readListRequest:filePath] isEqualToDictionary:@{@"data": @[]}]);

    NSMutableArray *events = [NSMutableArray new];
    for (int i = 0; i < sizeof(testdata) / sizeof(testdata[0]); i++) {
        [events addObject:testdata[i]];
        [self writeEvents:events fromPath:tmpPath toPath:filePath];
        XCTAssertTrue([[self readListRequest:filePath] isEqualToDictionary:@{@"data": events}]);
    }

}

- (void)writeEvents:(NSArray *)events fromPath:(NSString *)fromPath toPath:(NSString *)toPath {
    NSFileHandle *recordIo;
    NSFileHandle *listRequest;

    XCTAssertNotNil(recordIo = [NSFileHandle fileHandleForWritingAtPath:fromPath]);
    for (NSDictionary *event in events) {
        SFRecordIoAppendRecord(recordIo, event);
    }
    [recordIo closeFile];

    XCTAssertNotNil(recordIo = [NSFileHandle fileHandleForReadingAtPath:fromPath]);
    XCTAssertNotNil(listRequest = [NSFileHandle fileHandleForWritingAtPath:toPath]);
    SFRecordIoToListRequestConverter *converter = [SFRecordIoToListRequestConverter new];
    XCTAssert([converter start:listRequest]);
    XCTAssert([converter convert:recordIo]);
    XCTAssert([converter end]);
    [recordIo closeFile];
    [listRequest closeFile];
}

- (NSDictionary *)readListRequest:(NSString *)filePath {
    NSFileHandle *handle;
    NSData *data;
    NSDictionary *listRequest;
    XCTAssertNotNil(handle = [NSFileHandle fileHandleForReadingAtPath:filePath]);
    XCTAssertNotNil(data = [handle readDataToEndOfFile]);
    XCTAssertNotNil(listRequest = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
    [handle closeFile];
    return listRequest;
}

@end
