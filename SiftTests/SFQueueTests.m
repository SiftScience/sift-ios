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
        .appendEventOnlyWhenDifferent = NO,
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
        .appendEventOnlyWhenDifferent = NO,
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

- (SFQueue *)makeQueue:(SFQueueConfig)config {
    return [[SFQueue alloc] initWithIdentifier:@"id" config:config archivePath:_archivePath];
}

@end
