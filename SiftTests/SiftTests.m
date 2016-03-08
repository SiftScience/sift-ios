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
    XCTAssertFalse([_sift appendEvent:[SFEvent eventWithType:nil path:nil fields:nil] withLocation:NO]);

    _sift.userId = @"1234";
    XCTAssertTrue([_sift appendEvent:[SFEvent eventWithType:nil path:nil fields:nil] withLocation:NO]);
}

@end
