// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFUtils.h"

#import "SFQueue.h"

@interface SFEventQueueTests : XCTestCase

@end

@implementation SFEventQueueTests {
    NSString *_archivePath;
}

- (void)setUp {
    [super setUp];
    NSString *rootDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _archivePath = [SFCacheDirPath() stringByAppendingPathComponent:rootDirName];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:_archivePath error:nil];
    [super tearDown];
}

- (void)testAppend {
    SFQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    SFQueue *queue = [self makeQueue:config];

    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path-1" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path-2" fields:nil]];

    NSArray *events = [queue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:0] path], @"path-0");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:1] path], @"path-1");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:2] path], @"path-2");
}

- (void)testArchive {
    SFQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    SFQueue *queue = [self makeQueue:config];

    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path-1" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path-2" fields:nil]];
    [queue archive];

    // Append after archive...
    [queue append:[SFEvent eventWithType:nil path:@"path-3" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path-4" fields:nil]];

    SFQueue *anotherQueue = [self makeQueue:config];
    NSArray *events = [anotherQueue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:0] path], @"path-0");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:1] path], @"path-1");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:2] path], @"path-2");
}

- (void)testReadyForUploadMoreThan {
    SFQueueConfig config = {
        .uploadWhenMoreThan = 1,
        .uploadWhenOlderThan = 3600,
    };
    SFQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);

    // We expect the first event to be uploaded immediately
    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    // We have to manually transfer because we don't have a Sift instance
    [queue transfer];

    // After the queue is flushed, it should not be ready after 1 event
    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertFalse(queue.readyForUpload);
    
    // Now that it's exceeded 1, we expect it to be ready
    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertTrue(queue.readyForUpload);
}

- (void)testReadyForUploadAfterWait {
    SFQueueConfig config = {
        .uploadWhenMoreThan = 5,
        .uploadWhenOlderThan = 1,
    };
    SFQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);
    
    // We expect the first event to be uploaded immediately
    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    // Don't manually transfer so that the queue holds one item
    
    // Sleep for 1.1 seconds (in excess of TTL)
    [NSThread sleepForTimeInterval:1.1];
    
    // Now the queue should be ready for upload
    XCTAssertTrue(queue.readyForUpload);
}

- (void)testReadyForUploadNoWait {
    SFQueueConfig config = {
        .uploadWhenMoreThan = 5,
        .uploadWhenOlderThan = 1,
    };
    SFQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);
    
    // We expect the first event to be uploaded immediately
    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    [queue transfer];
    
    // Should not have uploaded the second event (not stale enough)
    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertFalse(queue.readyForUpload);
}

- (void)testReadyForUploadOlderThan {
    SFQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 1,
    };
    SFQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);

    [queue append:[SFEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertFalse(queue.readyForUpload);
    [NSThread sleepForTimeInterval:1.1];
    XCTAssertTrue(queue.readyForUpload);
}

- (void)testAppendSameEventImmediately {
    SFQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    SFQueue *queue = [self makeQueue:config];

    [queue append:[SFEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path" fields:nil]];

    NSArray *events = [queue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:0] path], @"path");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:1] path], @"path");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:2] path], @"path");

    [queue append:[SFEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SFEvent eventWithType:nil path:@"path" fields:nil]];

    events = [queue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:0] path], @"path");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:1] path], @"path");
    XCTAssertEqualObjects([(SFEvent *)[events objectAtIndex:2] path], @"path");
}

- (SFQueue *)makeQueue:(SFQueueConfig)config {
    return [[SFQueue alloc] initWithIdentifier:@"id" config:config archivePath:_archivePath
                                          sift:nil];
}

@end
