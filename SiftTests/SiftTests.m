// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFUtils.h"

#import "Sift.h"
#import "Sift+Private.h"

@interface SiftTests : XCTestCase

@end

@implementation SiftTests {
    Sift *_sift;
    NSString *_rootDirPath;
}

- (void)setUp {
    [super setUp];
    NSString *rootDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:rootDirName];
    _sift = [[Sift alloc] initWithRootDirPath:_rootDirPath];
}

- (void)tearDown {
    [[NSFileManager defaultManager] removeItemAtPath:_rootDirPath error:nil];
    [super tearDown];
}

- (void)testAppendEvent {
    [_sift unsetUserId];
    XCTAssertTrue([_sift appendEvent:[SFEvent eventWithType:nil path:nil fields:nil]]);

    [_sift setUserId:@"1234"];
    XCTAssertTrue([_sift appendEvent:[SFEvent eventWithType:nil path:nil fields:nil]]);
}

@end
