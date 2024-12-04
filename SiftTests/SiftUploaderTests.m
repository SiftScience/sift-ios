// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftEvent.h"
#import "Sift.h"
#import "Sift+Private.h"

#import "SiftUploader.h"

#import "SiftStubHttpProtocol.h"

@interface SiftUploader (Testing)
/** For testing. */
- (instancetype)initWithArchivePath:(NSString *)archivePath sift:(Sift *)sift config:(NSURLSessionConfiguration *)config backoffBase:(int64_t)backoffBase networkRetryTimeout:(int64_t)networkRetryTimeout;
@end

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
    _uploader = [[SiftUploader alloc] initWithArchivePath:nil sift:_sift config:SFMakeStubConfig() backoffBase:NSEC_PER_SEC/100 networkRetryTimeout: NSEC_PER_SEC / 1000];

    SFHttpStub *stub = [SFHttpStub sharedInstance];
    [stub.stubbedStatusCodes removeAllObjects];
    [stub.capturedRequests removeAllObjects];
}

- (void)tearDown {
    _uploader = nil;
    _sift = nil;
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

    int rejectedLimitCount = 60;
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
    
    int rejectedLimitCount = 61;
    for (int i = 0; i < rejectedLimitCount; i++) {
        // Simulate a network error response (status code 1 hardcoded for network errors).
        [stub.stubbedStatusCodes addObject:@1];
    }
    
    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];
    
    XCTWaiter *waiter = [[XCTWaiter alloc] init];
    XCTWaiterResult result = [waiter waitForExpectations:@[expectation] timeout:3.0];
    
    // The waiter should time out because it's waiting for the final call (call 61) to be made.
    // However, the call is not made because the system stops retrying after 60 failed attempts (SF_DEFAULT_NETWORK_MAX_RETRIES).
    XCTAssertEqual(result, XCTWaiterResultTimedOut);
    // Assert that no more than 60(SF_DEFAULT_NETWORK_MAX_RETRIES) calls were made
    XCTAssertEqual(stub.capturedRequests.count, 60);
    // 1 stub should still be in the queue
    XCTAssertEqual(stub.stubbedStatusCodes.count, 1);
}

- (void)testUploadNetworkErrorsMaxRetriesNotReached {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };
    
    int rejectedLimitCount = 59;
    for (int i = 0; i < rejectedLimitCount; i++) {
        // Simulate a network error response (status code 1 hardcoded for network errors).
        [stub.stubbedStatusCodes addObject:@1];
    }
    
    int successfullRequests = 1;
    for (int i = 0; i < successfullRequests; i++) {
        [stub.stubbedStatusCodes addObject:@200];
    }
    
    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];
    
    [self waitForExpectationsWithTimeout:3.0 handler:nil];

    XCTAssertEqual(stub.capturedRequests.count, rejectedLimitCount + successfullRequests);
    XCTAssertEqual(stub.stubbedStatusCodes.count, 0);
}

- (void)testUploadNetworkAndHttpErrorsMaxRetriesNotReached {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };
    
    int rejectedLimitCount = 59;
    for (int i = 0; i < rejectedLimitCount; i++) {
        // Simulate a network error response (status code 1 hardcoded for network errors).
        [stub.stubbedStatusCodes addObject:@1];
    }
    
    int rejectedHttpErrorLimitCount = 2;
    for (int i = 0; i < rejectedHttpErrorLimitCount; i++) {
        [stub.stubbedStatusCodes addObject:@500];
    }
    
    int successfullRequests = 1;
    for (int i = 0; i < successfullRequests; i++) {
        [stub.stubbedStatusCodes addObject:@200];
    }
    
    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];
    
    [self waitForExpectationsWithTimeout:3.0 handler:nil];

    
    XCTAssertEqual(stub.capturedRequests.count, rejectedLimitCount + successfullRequests + rejectedHttpErrorLimitCount);
    // verify that max retries for network and http errors are not reached
    XCTAssertEqual(stub.stubbedStatusCodes.count, 0);
}

@end
