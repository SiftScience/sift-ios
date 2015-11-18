// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFQueueDirs.h"
#import "SFUtils.h"

#import "SFQueue.h"
#import "SFQueue+Private.h"

@interface SFEventQueueTests : XCTestCase

@end

@implementation SFEventQueueTests {
    NSString *_rootDirName;
    NSString *_rootDirPath;
    SFQueueDirs *_queueDirs;
    NSOperationQueue *_operationQueue;
}

- (void)setUp {
    [super setUp];
    _rootDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:_rootDirName];
    _queueDirs = [[SFQueueDirs alloc] initWithRootDirPath:_rootDirPath];
    _operationQueue = [NSOperationQueue new];
}

- (void)tearDown {
    [_queueDirs removeRootDir];
    [super tearDown];
}

- (void)testQueueConfigNoRotation {
    SFQueueConfig config = {
        .appendEventOnlyWhenDifferent = NO,
        .rotateWhenLargerThan = 65536,
        .rotateWhenOlderThan = 3600,
    };
    SFQueue *queue = [self makeQueue:config];

    NSDictionary *events[] = {
        @{@"key1": @"value1"},
        @{@"key2": @"value2"},
        @{@"key3": @"value3"},
    };
    for (int i = 0; i < sizeof(events) / sizeof(events[0]); i++) {
        [queue append:events[i]];
    }
    [_operationQueue waitUntilAllOperationsAreFinished];

    // According to the config above, this should not rotate.
    [self assertDirContent:@"queue-id" contents:@[@"data"]];
}

- (void)testQueueConfigRotation {
    SFQueueConfig config = {
        .appendEventOnlyWhenDifferent = NO,
        .rotateWhenLargerThan = 0,
        .rotateWhenOlderThan = 3600,
    };
    SFQueue *queue = [self makeQueue:config];

    [queue append:@{@"key-1": @"value-1"}];
    [_operationQueue waitUntilAllOperationsAreFinished];
    [self assertDirContent:@"queue-id" contents:@[@"data-0"]];

    [queue append:@{@"key-2": @"value-2"}];
    [_operationQueue waitUntilAllOperationsAreFinished];
    [self assertDirContent:@"queue-id" contents:@[@"data-0", @"data-1"]];

    [queue append:@{@"key-3": @"value-3"}];
    [_operationQueue waitUntilAllOperationsAreFinished];
    [self assertDirContent:@"queue-id" contents:@[@"data-0", @"data-1", @"data-2"]];
}

- (void)testQueueConfigOnlyDifferent {
    SFQueueConfig config = {
        .appendEventOnlyWhenDifferent = YES,
        .rotateWhenLargerThan = 65536,
        .rotateWhenOlderThan = 3600,
    };
    SFQueue *queue = [self makeQueue:config];

    for (int i = 0; i < 10; i++) {
        [queue append:@{@"key1": @"value1"}];
        [_operationQueue waitUntilAllOperationsAreFinished];
        [self assertDirContent:@"queue-id" contents:@[@"data"]];
    }

    [self rotate:@"id"];
    [self assertDirContent:@"queue-id" contents:@[@"data-0"]];
    for (int i = 0; i < 10; i++) {
        [queue append:@{@"key1": @"value1"}];
        [_operationQueue waitUntilAllOperationsAreFinished];
        [self assertDirContent:@"queue-id" contents:@[@"data-0"]];
    }

    for (int i = 0; i < 10; i++) {
        [queue append:@{@"key2": @"value2"}];
        [_operationQueue waitUntilAllOperationsAreFinished];
        [self assertDirContent:@"queue-id" contents:@[@"data", @"data-0"]];
    }
}

- (SFQueue *)makeQueue:(SFQueueConfig)config {
    return [[SFQueue alloc] initWithIdentifier:@"id" config:config operationQueue:_operationQueue queueDirs:_queueDirs];
}

- (void)rotate:(NSString *)identifier {
    [_queueDirs useDir:identifier withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles rotateFile];
    }];
}

- (void)assertDirContent:(NSString *)dirName contents:(NSArray *)contents {
    XCTAssert([contents isEqualToArray:[self dirContents:dirName]]);
}

- (NSArray *)dirContents:(NSString *)dirName {
    NSString *path = [_rootDirPath stringByAppendingPathComponent:dirName];
    NSError *error;
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    XCTAssertNotNil(fileNames, @"Could not list contents of \"%@\" due to %@", path, [error localizedDescription]);
    return [fileNames sortedArrayUsingSelector:@selector(compare:)];
}

@end
