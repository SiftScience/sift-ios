//  Copyright © 2024 Sift Science. All rights reserved.

@import XCTest;

#import "SiftEvent.h"
#import "Sift.h"
#import "Sift+Private.h"

#import "SiftUploader.h"

#import "SiftStubHttpProtocol.h"

@interface SiftUploaderBackoffTests : XCTestCase

@end

@implementation SiftUploaderBackoffTests {
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
    
    // Set backoff = 5 seconds to test calculation of max retries for network errors
    _uploader = [[SiftUploader alloc] initWithArchivePath:nil sift:_sift config:SFMakeStubConfig() backoffBase:5 * NSEC_PER_SEC networkRetryTimeout: 60 * NSEC_PER_SEC];
    
    SFHttpStub *stub = [SFHttpStub sharedInstance];
    [stub.stubbedStatusCodes removeAllObjects];
    [stub.capturedRequests removeAllObjects];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testUploadMaxRetriesForNetworkErrorsWithBaseBackoff {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };
    
    // add stubs to the queue
    int rejectedLimitCount = 100;
    for (int i = 0; i < rejectedLimitCount; i++) {
        // Simulate a network error response (status code 1 hardcoded for network errors).
        [stub.stubbedStatusCodes addObject:@1];
    }
    
    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];
    
    XCTWaiter *waiter = [[XCTWaiter alloc] init];
    // max network retries should not exceed 1 min
    XCTWaiterResult result = [waiter waitForExpectations:@[expectation] timeout:61.0];
    
    // The waiter should time out because it's waiting for the final call (rejectedLimitCount = 100) to be made.
    // However, the call is not made because the system stops retrying after max retries for network failed attempts (60 / backoffBase).
    XCTAssertEqual(result, XCTWaiterResultTimedOut);
    // Assert that no more than 12 (60 / backoffBase) calls were made
    XCTAssertEqual(stub.capturedRequests.count, 60 / 5);
    // 88 (initial stubs in the queue minus 12 captured requests) stubs should still be in the queue
    XCTAssertEqual(stub.stubbedStatusCodes.count, rejectedLimitCount - 60/5);
}

@end
