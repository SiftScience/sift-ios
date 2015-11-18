// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFUtils.h"

#import "SFQueueDirs.h"

@interface SFQueueDirsTests : XCTestCase

@end

@implementation SFQueueDirsTests {
    NSString *_rootDirName;
    NSString *_rootDirPath;
    SFQueueDirs *_queueDirs;
}

- (void)setUp {
    [super setUp];
    _rootDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:_rootDirName];
    _queueDirs = [[SFQueueDirs alloc] initWithRootDirPath:_rootDirPath];
}

- (void)tearDown {
    [_queueDirs removeRootDir];
    [super tearDown];
}

- (void)testQueueDirs {
    XCTAssertEqualObjects(@[], [self dirContents]);

    XCTAssert([_queueDirs addDir:@""]);
    XCTAssertEqualObjects(@[@"queue"], [self dirContents]);

    XCTAssert([_queueDirs addDir:@"id-1"]);
    {
        NSArray *expect = @[@"queue", @"queue-id-1"];
        XCTAssertEqualObjects(expect, [self dirContents]);
    }

    XCTAssert([_queueDirs addDir:@"id-1"]);

    XCTAssert([_queueDirs addDir:@"id-2"]);
    {
        NSArray *expect = @[@"queue", @"queue-id-1", @"queue-id-2"];
        XCTAssertEqualObjects(expect, [self dirContents]);
    }

    XCTAssert([_queueDirs removeDir:@"" purge:NO]);
    {
        NSArray *expect = @[@"queue", @"queue-id-1", @"queue-id-2"];
        XCTAssertEqualObjects(expect, [self dirContents]);
    }

    XCTAssert(![_queueDirs removeDir:@"" purge:NO]);

    [_queueDirs useDir:@"" withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        XCTAssertNotNil(rotatedFiles);  // Created on-demand.
        return YES;
    }];

    [_queueDirs useDir:@"id-1" withBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        XCTAssertNotNil(rotatedFiles);
        return YES;
    }];
}

- (void)testQueueDirsScanDirContentsDuringInit {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error;
    for (NSString *dirName in @[@"queue", @"queue-id-1", @"garbage", @"queuexxx"]) {
        XCTAssert([manager createDirectoryAtPath:[_rootDirPath stringByAppendingPathComponent:dirName] withIntermediateDirectories:YES attributes:nil error:&error]);
    }
    SFQueueDirs *queueDirs = [[SFQueueDirs alloc] initWithRootDirPath:_rootDirPath];
    XCTAssert(queueDirs.numDirs == 2);
}

- (NSArray *)dirContents {
    NSError *error;
    NSArray *paths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_rootDirPath error:&error];
    XCTAssertNotNil(paths, @"Could not list root dir \"%@\" contents due to %@", _rootDirPath, [error localizedDescription]);
    return [paths sortedArrayUsingSelector:@selector(compare:)];
}

@end
