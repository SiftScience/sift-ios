// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftUtils.h"

#import "Sift.h"
#import "Sift+Private.h"
#import "SiftIosAppStateCollector.h"
#import "SiftIosAppStateCollector+Private.h"

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
    XCTAssertTrue([_sift appendEvent:[SiftEvent eventWithType:nil path:nil fields:nil]]);

    [_sift setUserId:@"1234"];
    XCTAssertTrue([_sift appendEvent:[SiftEvent eventWithType:nil path:nil fields:nil]]);
    
    XCTAssertFalse([_sift appendEvent:[SiftEvent eventWithType:nil path:nil fields:@{@"key": @"value"}] toQueue:nil]); //When queue is missing
    XCTAssertFalse([_sift appendEvent:[SiftEvent eventWithType:nil path:nil fields:@{@"key": @5436}]]); // Drop event due to incorrect contents
}

- (void)testAddEventQueue {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    XCTAssertTrue([_sift addEventQueue: @"sift-test-default" config: config]);
}

- (void)testHasEventQueue {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    XCTAssertFalse([_sift hasEventQueue:@"sift-test-default"]);
    XCTAssertTrue([_sift addEventQueue: @"sift-test-default" config: config]);
    XCTAssertTrue([_sift hasEventQueue:@"sift-test-default"]);
}

- (void)testRemoveEvent {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    XCTAssertTrue([_sift addEventQueue: @"sift-test-default" config: config]);
    XCTAssertTrue([_sift hasEventQueue:@"sift-test-default"]);
    XCTAssertTrue([_sift removeEventQueue: @"sift-test-default"]);
    XCTAssertFalse([_sift removeEventQueue: @"sift-test-default"]); // Already removed
    XCTAssertFalse([_sift hasEventQueue:@"sift-test-default"]);
}

- (void)testSetAccountId {
    [_sift setAccountId:@"11"];
    XCTAssertEqual(_sift.accountId, @"11");
}

- (void)testSetBeaconKey {
    [_sift setBeaconKey:@"xxxx"];
    XCTAssertEqual(_sift.beaconKey, @"xxxx");
}

- (void)testSetUserId {
    [_sift setUserId:@"1234"];
    XCTAssertEqual(_sift.userId, @"1234");
}

- (void)testDisallowCollectingLocationData {
    XCTAssertFalse(_sift.disallowCollectingLocationData);
    [_sift setDisallowCollectingLocationData:YES];
    XCTAssertTrue(_sift.disallowCollectingLocationData);
}

- (void)testFailedUploadWhenNoEvent {
    _sift.accountId = @"account_id";
    _sift.beaconKey = @"beacon_key";
    _sift.userId = @"user_id";
    _sift.serverUrlFormat = @"mock+https://127.0.0.1/v3/accounts/%@/mobile_events";
    XCTAssertFalse([_sift upload: YES]);
}

- (void)testBucketArchive {
    SiftIosAppStateCollector *_iosAppStateCollector = [[SiftIosAppStateCollector alloc] initWithArchivePath: @"test_app_state_collector"];
    [_iosAppStateCollector archive];
    NSData *data = [NSData dataWithContentsOfFile:@"test_app_state_collector"];
    NSDictionary *actual;
    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    XCTAssertNotNil(actual);
}

- (void)testCollectWithTitle {
    SiftIosAppStateCollector *_iosAppStateCollector = [[SiftIosAppStateCollector alloc] initWithArchivePath: @"test_app_state_collector"];
    [_iosAppStateCollector requestCollectionWithTitle:nil];
    
    XCTAssertTrue([_sift hasEventQueue: [_sift defaultQueueIdentifier]]);
}

- (void)testCollect {
    SiftQueueConfig config = {
        .uploadWhenMoreThan = 65536,
        .uploadWhenOlderThan = 3600,
    };
    [_sift addEventQueue: @"sift-devprops" config: config];
    
    [_sift collect];
    
    XCTAssertTrue([_sift hasEventQueue: [_sift defaultQueueIdentifier]]);
    XCTAssertTrue([_sift hasEventQueue: @"sift-devprops"]);
}

@end
