// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftEvent.h"
#import "Sift.h"
#import "Sift+Private.h"

#import "SiftUploader.h"

#import "SiftStubHttpProtocol.h"

@interface SiftEventFileMultiUploaderTests : XCTestCase

@end

@implementation SiftEventFileMultiUploaderTests {
    Sift *_sift;
    SiftUploader *_uploader;
}

- (void)setUp {
    [super setUp];

    _sift = [[Sift alloc] init];  // Don't call initWithRootDirPath.
    _sift.accountId = @"account_id_1";
    _sift.beaconKey = @"beacon_key_1";
    
    AccountKey *accountKey1 = [AccountKey new];
    accountKey1.accountId = @"account_id_2";
    accountKey1.beaconKey = @"beacon_key_2";

    AccountKey *accountKey2 = [AccountKey new];
    accountKey2.accountId = @"account_id_3";
    accountKey2.beaconKey = @"beacon_key_3";
    
    NSArray<AccountKey *> *accountKeysArray = @[accountKey1, accountKey2];
    
    _sift.accountKeys = accountKeysArray;
    _sift.userId = @"user_id";
    _sift.serverUrlFormat = @"mock+https://127.0.0.1/v3/accounts/%@/mobile_events";

    // Disable exponential backoff with baseoffBase = 0.
    _uploader = [[SiftUploader alloc] initWithArchivePath:nil sift:_sift config:SFMakeStubConfig() backoffBase:0];

    SFHttpStub *stub = [SFHttpStub sharedInstance];
    [stub.stubbedStatusCodes removeAllObjects];
    [stub.capturedRequests removeAllObjects];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testUpload {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };

    [stub.stubbedStatusCodes addObject:@200];
    [stub.stubbedStatusCodes addObject:@200];
    [stub.stubbedStatusCodes addObject:@200];

    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertEqual(stub.stubbedStatusCodes.count, 0);
    XCTAssertEqual(stub.capturedRequests.count, 3);
}

- (void)testUploadRejected {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };

    // SFUploader takes three rejects.
    [stub.stubbedStatusCodes addObject:@500];
    [stub.stubbedStatusCodes addObject:@500];
    [stub.stubbedStatusCodes addObject:@500];

    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertEqual(stub.stubbedStatusCodes.count, 0);
    XCTAssertEqual(stub.capturedRequests.count, 3);
}

- (void)testUploadHttpError {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };

    [stub.stubbedStatusCodes addObject:@400];
    [stub.stubbedStatusCodes addObject:@400];
    [stub.stubbedStatusCodes addObject:@400];

    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertEqual(stub.capturedRequests.count, 3);
}

@end
