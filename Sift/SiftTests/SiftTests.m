// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFQueueConfig.h"
#import "SFQueueDirs.h"
#import "SFRecordIo.h"
#import "SFRotatedFiles.h"
#import "SFUploader.h"
#import "SFUploader+Private.h"
#import "SFUtils.h"

#import "Sift.h"
#import "Sift+Private.h"

#import "SFStubHttpProtocol.h"

@interface SiftTests : XCTestCase

@end

@implementation SiftTests {
    NSString *_rootDirPath;
    NSOperationQueue *_operationQueue;
    SFQueueDirs *_queueDirs;
    SFUploader *_uploader;
    Sift *_sift;
}

- (void)setUp {
    [super setUp];
    NSString *rootDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:rootDirName];
    _queueDirs = [[SFQueueDirs alloc] initWithRootDirPath:_rootDirPath];
    _operationQueue = [NSOperationQueue new];
    _queueDirs = [[SFQueueDirs alloc] initWithRootDirPath:_rootDirPath];
    _uploader = [[SFUploader alloc] initWithRootDirPath:_rootDirPath queueDirs:_queueDirs operationQueue:_operationQueue config:SFMakeStubConfig()];
    _sift = [[Sift alloc] initWithRootDirPath:_rootDirPath operationQueue:_operationQueue queueDir:_queueDirs uploader:_uploader];
    _sift.serverUrlFormat = @"mock+https://127.0.0.1/v3/accounts/%@/mobile_events";
    _sift.uploadPeriod = 0; // Cancel background upload.
}

- (void)tearDown {
    NSError *error;
    XCTAssert([[NSFileManager defaultManager] removeItemAtPath:_rootDirPath error:&error], @"Could not remove \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
    [super tearDown];
}

- (void)testCustomEventQueue {
    SFQueueConfig config = {
        .appendEventOnlyWhenDifferent = NO,
        .rotateWhenLargerThan = 0,
        .rotateWhenOlderThan = 0,
    };
    [_sift addEventQueue:@"q1" config:config];

    NSMutableArray *requests = SFCapturedRequests();
    for (int repeat = 0; repeat < 1; repeat++) {
        [requests removeAllObjects];

        NSDictionary *events[] = {
            @{@"key1": @"value1", @"key2": @"value2"},
            @{@"key": @"value"},
            @{},
        };
        int numEvents = sizeof(events) / sizeof(events[0]);
        for (int i = 0; i < numEvents; i++) {
            SFEvent *event = [SFEvent eventWithPath:@"path" mobileEventType:@"mobile_event" userId:@"user_id" fields:events[i]];
            [_sift appendEvent:event toQueue:@"q1"];
        }

        // Force rotating files.
        BOOL okay = [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
            XCTAssert([rotatedFiles rotateFile]);
            return YES;
        }];
        XCTAssert(okay);

        XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for uploads"];
        _uploader.completionHandler = ^{
            [expectation fulfill];
        };

        _sift.accountId = @"account_id";
        _sift.beaconKey = @"beacon_key";
        XCTAssert([_sift upload]);
        [self waitForExpectationsWithTimeout:5.0 handler:nil];

        // Unfortunately we can't examine the HTTP body because Apple doesn't seem to give it to us :(
        XCTAssert(1 == requests.count);
    }
}

- (void)testAddRemoveEventQueue {
    SFQueueConfig config;

    XCTAssert([_sift addEventQueue:@"q1" config:config]);
    XCTAssert(![_sift addEventQueue:@"q1" config:config]);

    XCTAssert([_sift removeEventQueue:@"" purge:NO]);  // The default event queue.
    XCTAssert(![_sift removeEventQueue:@"" purge:NO]);

    XCTAssert([_sift removeEventQueue:@"q1" purge:YES]);
    XCTAssert(![_sift removeEventQueue:@"q1" purge:YES]);

    XCTAssert(![_sift removeEventQueue:@"no-such-queue" purge:NO]);
}

@end
