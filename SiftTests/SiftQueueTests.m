// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftUtils.h"

#import "SiftQueue.h"

@interface SiftEventQueueTests : XCTestCase

@end

@implementation SiftEventQueueTests {
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
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    SiftQueue *queue = [self makeQueue:config];

    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path-1" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path-2" fields:nil]];

    NSArray *events = [queue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:0] path], @"path-0");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:1] path], @"path-1");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:2] path], @"path-2");
}

- (void)testArchive {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    SiftQueue *queue = [self makeQueue:config];

    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path-1" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path-2" fields:nil]];
    [queue archive];

    // Append after archive...
    [queue append:[SiftEvent eventWithType:nil path:@"path-3" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path-4" fields:nil]];

    SiftQueue *anotherQueue = [self makeQueue:config];
    NSArray *events = [anotherQueue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:0] path], @"path-0");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:1] path], @"path-1");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:2] path], @"path-2");
}

- (void)testReadyForUploadMoreThan {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 1,
        .uploadWhenOlderThan = 3600,
    };
    SiftQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);

    // We expect the first event to be uploaded immediately
    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    // We have to manually transfer because we don't have a Sift instance
    [queue transfer];

    // After the queue is flushed, it should not be ready after 1 event
    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertFalse(queue.readyForUpload);
    
    // Now that it's exceeded 1, we expect it to be ready
    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertTrue(queue.readyForUpload);
}

- (void)testReadyForUploadAfterWait {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 5,
        .uploadWhenOlderThan = 1,
    };
    SiftQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);
    
    // We expect the first event to be uploaded immediately
    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    // Don't manually transfer so that the queue holds one item
    
    // Sleep for 1.1 seconds (in excess of TTL)
    [NSThread sleepForTimeInterval:1.1];
    
    // Now the queue should be ready for upload
    XCTAssertTrue(queue.readyForUpload);
}

- (void)testReadyForUploadNoWait {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 5,
        .uploadWhenOlderThan = 1,
    };
    SiftQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);
    
    // We expect the first event to be uploaded immediately
    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    [queue transfer];
    
    // Should not have uploaded the second event (not stale enough)
    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertFalse(queue.readyForUpload);
}

- (void)testReadyForUploadOlderThan {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 1,
    };
    SiftQueue *queue = [self makeQueue:config];
    XCTAssertFalse(queue.readyForUpload);

    [queue append:[SiftEvent eventWithType:nil path:@"path-0" fields:nil]];
    XCTAssertFalse(queue.readyForUpload);
    [NSThread sleepForTimeInterval:1.1];
    XCTAssertTrue(queue.readyForUpload);
}

- (void)testAppendSameEventImmediately {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    SiftQueue *queue = [self makeQueue:config];

    [queue append:[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path" fields:nil]];

    NSArray *events = [queue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:0] path], @"path");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:1] path], @"path");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:2] path], @"path");

    [queue append:[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [queue append:[SiftEvent eventWithType:nil path:@"path" fields:nil]];

    events = [queue transfer];
    XCTAssertEqual(events.count, 3);
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:0] path], @"path");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:1] path], @"path");
    XCTAssertEqualObjects([(SiftEvent *)[events objectAtIndex:2] path], @"path");
}

- (SiftQueue *)makeQueue:(SiftQueueConfig)config {
    return [[SiftQueue alloc] initWithIdentifier:@"id" config:config archivePath:_archivePath
                                          sift:nil];
}

@end
