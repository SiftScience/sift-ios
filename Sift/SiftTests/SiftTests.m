// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFEventFileUploader.h"
#import "SFEventFileUploader+Internal.h"
#import "SFUtil.h"

#import "Sift.h"
#import "Sift+Internal.h"

#import "SFStubHttpProtocol.h"

@interface SiftTests : XCTestCase

@end

@implementation SiftTests {
    NSString *_rootDirPath;
    Sift *_sift;
}

- (void)setUp {
    [super setUp];
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)]];
    _sift = [[Sift alloc] initWithRootDirPath:_rootDirPath];

    // HACK: Replace _sift.uploader object.
    _sift.uploader = SFStubHttpProtocolMakeUploader(_sift.operationQueue, _sift.manager, _rootDirPath);
}

- (void)tearDown {
    NSError *error;
    XCTAssert([[NSFileManager defaultManager] removeItemAtPath:_rootDirPath error:&error], @"Could not remove \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
    [super tearDown];
}

- (void)testCustomEventQueue {
    SFConfig config = {
        .trackEventDifferenceOnly = NO,
        .rotateCurrentEventFileInterval = 0,
        .rotateCurrentEventFileIfOlderThan = 0,
        .rotateCurrentEventFileIfLargerThan = 4096,
        .uploadEventFilesInterval = 0,
    };

    NSDictionary *events[] = {
        @{@"key1": @"value1", @"key2": @"value2"},
        @{@"key": @"value"},
        @{},
    };
    int numEvents = sizeof(events) / sizeof(events[0]);
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for uploads"];
    NSMutableArray *count = [NSMutableArray arrayWithObjects:@0, nil];
    _sift.uploader.completionHandler = ^{
        int newCount = ((NSNumber *)count[0]).intValue + 1;
        count[0] = [NSNumber numberWithInt:newCount];
        if (newCount >= numEvents) {
            [expectation fulfill];
        }
    };

    [_sift addEventQueue:@"q1" config:config];

    for (int i = 0; i < numEvents; i++) {
        [_sift event:events[i] identifier:@"q1"];
    }

    [self waitForExpectationsWithTimeout:5.0 handler:nil];
}

- (void)testAddRemoveEventQueue {
    SFConfig config = {
        .trackEventDifferenceOnly = NO,
        .rotateCurrentEventFileInterval = 0,
        .rotateCurrentEventFileIfOlderThan = 0,
        .rotateCurrentEventFileIfLargerThan = 0,
        .uploadEventFilesInterval = 0,
    };

    XCTAssert([_sift addEventQueue:@"q1" config:config]);
    XCTAssert(![_sift addEventQueue:@"q1" config:config]);

    XCTAssert([_sift removeEventQueue:@""]);  // The default event queue.
    XCTAssert(![_sift removeEventQueue:@"no-such-queue"]);
}

@end
