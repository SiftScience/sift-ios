// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftEvent.h"
#import "Sift.h"
#import "Sift+Private.h"

#import "SiftUploader.h"

#import "SiftStubHttpProtocol.h"

@interface SiftEventFileUploaderTests : XCTestCase

@end

@implementation SiftEventFileUploaderTests {
    Sift *_sift;
    SiftUploader *_uploader;
}

- (void)setUp {
    [super setUp];

    _sift = [[Sift alloc] init];  // Don't call initWithRootDirPath.
    _sift.accountId = @"account_id";
    _sift.beaconKey = @"beacon_key";
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

    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertEqual(stub.stubbedStatusCodes.count, 0);
    XCTAssertEqual(stub.capturedRequests.count, 1);
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

    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];

    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    XCTAssertEqual(stub.capturedRequests.count, 1);
}

- (void)testUploadWithNetworkError {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };

    int rejectedLimitCount = 3;
    for (int i = 0; i < rejectedLimitCount; i++) {
        // Simulate a network error response (status code 1 hardcoded for network errors).
        [stub.stubbedStatusCodes addObject:@1];
    }

    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];

    [self waitForExpectationsWithTimeout:3.0 handler:nil];

    XCTAssertEqual(stub.capturedRequests.count, rejectedLimitCount);
    XCTAssertEqual(stub.stubbedStatusCodes.count, 0);
}

- (void)testUploadWithNetworkErrorAndTimeout {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };
    
    int rejectedLimitCount = 4;
    for (int i = 0; i < rejectedLimitCount; i++) {
        // Simulate a network error response (status code 1 hardcoded for network errors).
        [stub.stubbedStatusCodes addObject:@1];
    }
    
    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];
    
    XCTWaiter *waiter = [[XCTWaiter alloc] init];
    XCTWaiterResult result = [waiter waitForExpectations:@[expectation] timeout:3.0];
    
    // The waiter should time out because it's waiting for the final call (call 4) to be made.
    // However, the call is not made because the system stops retrying after three failed attempts (SF_REJECT_LIMIT).
    XCTAssertEqual(result, XCTWaiterResultTimedOut);
    // Assert that no more than 3(SF_REJECT_LIMIT) calls were made
    XCTAssertEqual(stub.capturedRequests.count, 3);
    // 1 stub should still be in the queue
    XCTAssertEqual(stub.stubbedStatusCodes.count, 1);
}

@end
