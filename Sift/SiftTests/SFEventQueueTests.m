// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFEventFileUploader.h"
#import "SFEventFileUploader+Internal.h"
#import "SFUtil.h"

#import "SFStubHttpProtocol.h"

#import "SFEventQueue.h"
#import "SFEventQueue+Internal.h"

@interface SFEventQueueTests : XCTestCase

@end

@implementation SFEventQueueTests {
    NSString *_rootDirPath;
    NSOperationQueue *_queue;
    SFEventFileManager *_manager;
    SFEventFileUploader *_uploader;
}

- (void)setUp {
    [super setUp];

    int testId = arc4random_uniform(1 << 20);
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"testdata-%07d", testId]];

    _queue = [NSOperationQueue new];

    _manager = [[SFEventFileManager alloc] initWithRootDir:_rootDirPath];

    _uploader = SFStubHttpProtocolMakeUploader(_queue, _manager, _rootDirPath);
}

- (void)tearDown {
    NSError *error;
    XCTAssert([[NSFileManager defaultManager] removeItemAtPath:_rootDirPath error:&error], @"Could not remove \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
    [super tearDown];
}

- (void)testQueueConfigNoRotation {
    SFConfig config = {
        .trackEventDifferenceOnly = NO,
        .rotateCurrentEventFileInterval = 0,
        .rotateCurrentEventFileIfOlderThan = 3600,
        .rotateCurrentEventFileIfLargerThan = 65536,
        .uploadEventFilesInterval = 3600,
    };
    SFEventQueue *queue = [[SFEventQueue alloc] initWithIdentifier:@"id" config:config queue:_queue manager:_manager uploader:_uploader];

    NSDictionary *events[] = {
        @{@"key1": @"value1"},
        @{@"key2": @"value2"},
        @{@"key3": @"value3"},
    };
    for (int i = 0; i < sizeof(events) / sizeof(events[0]); i++) {
        [queue append:events[i]];
    }
    [_queue waitUntilAllOperationsAreFinished];
    XCTAssertEqualObjects(@[@"events"], [self dirContents:@"id"]);

    // According to the config above, this should not rotate.
    [queue checkOrRotateCurrentEventFile];
    XCTAssertEqualObjects(@[@"events"], [self dirContents:@"id"]);
}

- (void)testQueueConfigRotation {
    SFConfig config = {
        .trackEventDifferenceOnly = NO,
        .rotateCurrentEventFileInterval = 0,
        .rotateCurrentEventFileIfOlderThan = 3600,
        .rotateCurrentEventFileIfLargerThan = 0,
        .uploadEventFilesInterval = 3600,
    };
    SFEventQueue *queue = [[SFEventQueue alloc] initWithIdentifier:@"id" config:config queue:_queue manager:_manager uploader:_uploader];

    [queue append:@{@"key-1": @"value-1"}];
    [_queue waitUntilAllOperationsAreFinished];
    {
        NSArray *expect = @[@"events-0"];
        XCTAssertEqualObjects(expect, [self dirContents:@"id"]);
    }

    [queue append:@{@"key-2": @"value-2"}];
    [_queue waitUntilAllOperationsAreFinished];
    {
        NSArray *expect = @[@"events-0", @"events-1"];
        XCTAssertEqualObjects(expect, [self dirContents:@"id"]);
    }

    [queue append:@{@"key-3": @"value-3"}];
    [_queue waitUntilAllOperationsAreFinished];
    {
        NSArray *expect = @[@"events-0", @"events-1", @"events-2"];
        XCTAssertEqualObjects(expect, [self dirContents:@"id"]);
    }
}

- (void)testQueueConfigDifferenceOnly {
    SFConfig config = {
        .trackEventDifferenceOnly = YES,
        .rotateCurrentEventFileInterval = 0,
        .rotateCurrentEventFileIfOlderThan = 3600,
        .rotateCurrentEventFileIfLargerThan = 0,
        .uploadEventFilesInterval = 3600,
    };
    SFEventQueue *queue = [[SFEventQueue alloc] initWithIdentifier:@"id" config:config queue:_queue manager:_manager uploader:_uploader];

    for (int i = 0; i < 10; i++) {
        [queue append:@{@"key1": @"value1"}];
        [_queue waitUntilAllOperationsAreFinished];
        NSArray *expect = @[@"events-0"];
        XCTAssertEqualObjects(expect, [self dirContents:@"id"]);
    }

    for (int i = 0; i < 10; i++) {
        [queue append:@{@"key2": @"value2"}];
        [_queue waitUntilAllOperationsAreFinished];
        NSArray *expect = @[@"events-0", @"events-1"];
        XCTAssertEqualObjects(expect, [self dirContents:@"id"]);
    }
}

- (NSArray *)dirContents:(NSString *)identifier {
    NSString *path = [_rootDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"events-%@", identifier]];
    NSError *error;
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    XCTAssertNotNil(fileNames, @"Could not list contents of \"%@\" due to %@", path, [error localizedDescription]);
    return [fileNames sortedArrayUsingSelector:@selector(compare:)];
}

@end
