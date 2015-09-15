// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFUtil.h"

#import "SFEventFileManager.h"

@interface SFEventFileManagerTests : XCTestCase

@end

@implementation SFEventFileManagerTests {
    NSString *_rootDirName;
    NSString *_rootDirPath;
    SFEventFileManager *_manager;
}

- (void)setUp {
    [super setUp];
    _rootDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:_rootDirName];
    _manager = [[SFEventFileManager alloc] initWithRootDir:_rootDirPath];
}

- (void)tearDown {
    [_manager removeRootDir];
    [super tearDown];
}

- (void)testEventFileManager {
    XCTAssertEqualObjects(@[], [self dirContents]);

    XCTAssert([_manager addEventStore:@""]);
    XCTAssertEqualObjects(@[@"events"], [self dirContents]);

    XCTAssert([_manager addEventStore:@"id-1"]);
    {
        NSArray *expect = @[@"events", @"events-id-1"];
        XCTAssertEqualObjects(expect, [self dirContents]);
    }

    XCTAssert([_manager addEventStore:@"id-1"]);

    XCTAssert([_manager addEventStore:@"id-2"]);
    {
        NSArray *expect = @[@"events", @"events-id-1", @"events-id-2"];
        XCTAssertEqualObjects(expect, [self dirContents]);
    }

    XCTAssert([_manager removeEventStore:@""]);
    {
        NSArray *expect = @[@"events", @"events-id-1", @"events-id-2"];
        XCTAssertEqualObjects(expect, [self dirContents]);
    }

    XCTAssert(![_manager removeEventStore:@""]);

    [_manager accessEventStore:@"" block:^BOOL (SFEventFileStore *store) {
        XCTAssertNil(store);
        return YES;
    }];

    [_manager accessEventStore:@"id-1" block:^BOOL (SFEventFileStore *store) {
        XCTAssertNotNil(store);
        return YES;
    }];
}

- (NSArray *)dirContents {
    NSError *error;
    NSArray *paths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:_rootDirPath error:&error];
    XCTAssertNotNil(paths, @"Could not list root dir \"%@\" contents due to %@", _rootDirPath, [error localizedDescription]);
    return [paths sortedArrayUsingSelector:@selector(compare:)];
}

@end
