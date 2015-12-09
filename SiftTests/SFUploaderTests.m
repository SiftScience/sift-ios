// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFDebug.h"
#import "SFEvent+Utils.h"
#import "SFQueueDirs.h"
#import "SFRecordIo.h"
#import "SFRotatedFiles.h"
#import "SFUtils.h"

#import "SFStubHttpProtocol.h"

#import "SFUploader.h"
#import "SFUploader+Private.h"

@interface SFEventFileUploaderTests : XCTestCase

@end

@implementation SFEventFileUploaderTests {
    NSString *_rootDirPath;
    NSOperationQueue *_operationQueue;
    SFQueueDirs *_queueDirs;
    SFUploader *_uploader;
}

- (void)setUp {
    [super setUp];
    NSString *rootDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:rootDirName];
    _operationQueue = [NSOperationQueue new];
    _queueDirs = [[SFQueueDirs alloc] initWithRootDirPath:[_rootDirPath stringByAppendingPathComponent:@"queues"]];
    _uploader = [[SFUploader alloc] initWithRootDirPath:[_rootDirPath stringByAppendingPathComponent:@"upload"] queueDirs:_queueDirs operationQueue:_operationQueue config:SFMakeStubConfig()];
}

- (void)tearDown {
    NSError *error;
    XCTAssert([[NSFileManager defaultManager] removeItemAtPath:_rootDirPath error:&error], @"Could not remove \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
    [super tearDown];
}

- (void)testUpload {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    _uploader.completionHandler = ^{
        [expectation fulfill];
    };

    // Create queue dirs.
    XCTAssert([_queueDirs addDir:@"id-1"]);
    XCTAssert([_queueDirs addDir:@"id-2"]);

    BOOL okay;

    // Create events and then rotate files.
    okay = [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        BOOL okay = [rotatedFiles writeCurrentFileWithBlock:^BOOL (NSFileHandle *handle) {
            NSDictionary *event = [[SFEvent eventWithPath:@"path" mobileEventType:@"mobile_event" userId:@"user_id" fields:@{@"key": @"value"}] makeEvent];
            XCTAssert(SFRecordIoAppendRecord(handle, event));
            return YES;
        }];
        XCTAssert(okay);
        XCTAssert([rotatedFiles rotateFile]);
        return YES;
    }];
    XCTAssert(okay);

    // Expect queue dirs should look like this...
    okay = [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        BOOL okay = [rotatedFiles accessFilesWithBlock:^BOOL (NSString *currentFilePath, NSArray *filePaths) {
            XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:currentFilePath isDirectory:nil]);
            XCTAssert(1 == filePaths.count);
            return YES;
        }];
        XCTAssert(okay);
        return YES;
    }];
    XCTAssert(okay);

    // Now, upload.
    [_uploader upload:@"mock+https://127.0.0.1/v3/accounts/%@/mobile_events" accountId:@"account_id" beaconKey:@"beacon_key" force:NO];
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // Expect queue dirs should look like this after upload...
    okay = [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        BOOL okay = [rotatedFiles accessFilesWithBlock:^BOOL (NSString *currentFilePath, NSArray *filePaths) {
            XCTAssert(![[NSFileManager defaultManager] fileExistsAtPath:currentFilePath isDirectory:nil]);
            XCTAssert(0 == filePaths.count);
            return YES;
        }];
        XCTAssert(okay);
        return YES;
    }];
    XCTAssert(okay);
}

@end
