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
- (BOOL)isNetworkBlockedError:(NSError*) error;
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
    _uploader = [[SiftUploader alloc] initWithArchivePath:nil sift:_sift config:SFMakeStubConfig() backoffBase:NSEC_PER_SEC/1000 networkRetryTimeout: 60 * NSEC_PER_SEC/1000 ];

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

- (void)testIsNetworkBlockedError {
    NSError *networkConnectionLostError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNetworkConnectionLost userInfo:nil];
    NSError *cannotFindHostError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotFindHost userInfo:nil];
    NSError *cannotConnectToHostError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorCannotConnectToHost userInfo:nil];
    NSError *dnsLookupFailedError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorDNSLookupFailed userInfo:nil];
    NSError *nonBlockingError = [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorTimedOut userInfo:nil];
    NSError *otherDomainError = [NSError errorWithDomain:@"OtherDomain" code:123 userInfo:nil];
    
    // Network blocking errors should return YES
    XCTAssertTrue([_uploader isNetworkBlockedError:networkConnectionLostError]);
    XCTAssertTrue([_uploader isNetworkBlockedError:cannotFindHostError]);
    XCTAssertTrue([_uploader isNetworkBlockedError:cannotConnectToHostError]);
    XCTAssertTrue([_uploader isNetworkBlockedError:dnsLookupFailedError]);
    
    // Non-blocking errors should return NO
    XCTAssertFalse([_uploader isNetworkBlockedError:nonBlockingError]);
    XCTAssertFalse([_uploader isNetworkBlockedError:otherDomainError]);
}

- (void)testNetworkBlockErrorSkipsRetry {
    SFHttpStub *stub = [SFHttpStub sharedInstance];

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    stub.completionHandler = ^{
        [expectation fulfill];
    };
    
    [stub.stubbedStatusCodes addObject:@(NSURLErrorNetworkConnectionLost)];
    
    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
    [_uploader upload:events];
    
    [self waitForExpectationsWithTimeout:3.0 handler:nil];
    
    // Verify that only one blocked request sent
    XCTAssertEqual(stub.capturedRequests.count, 1);
    XCTAssertEqual(stub.stubbedStatusCodes.count, 0);
}

- (void)testPause {
    SFHttpStub *stub = [SFHttpStub sharedInstance];
    [stub.stubbedStatusCodes addObject:@(NSURLErrorNetworkConnectionLost)];
    [stub.stubbedStatusCodes addObject:@(NSURLErrorNetworkConnectionLost)];
    
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    expectation.inverted = YES;
    stub.completionHandler = ^{};
    
    NSMutableArray *batches = [_uploader valueForKey:@"_batches"];
    NSArray *events = @[[SiftEvent eventWithType:nil path:@"path" fields:nil]];
        
    dispatch_source_t timer = [_uploader valueForKey:@"_source"];
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, NSEC_PER_SEC / 100, NSEC_PER_SEC);

    [_uploader pause];
    XCTAssertTrue([[_uploader valueForKey:@"_isPaused"] boolValue]);
    
    [batches addObject:events];
    [batches addObject:events];

    [self waitForExpectationsWithTimeout:0.1 handler:nil];
    
    // Verify that only one blocked request sent
    XCTAssertEqual(stub.capturedRequests.count, 1);
    XCTAssertEqual(stub.stubbedStatusCodes.count, 1);
    
    // Test that multiple pause calls don't cause issues
    [_uploader pause];
    XCTAssertTrue([[_uploader valueForKey:@"_isPaused"] boolValue]);
}

- (void)testResume {
    [_uploader pause];
    XCTAssertTrue([[_uploader valueForKey:@"_isPaused"] boolValue]);
    
    [_uploader resume];
    XCTAssertFalse([[_uploader valueForKey:@"_isPaused"] boolValue]);
    // Test that multiple resume calls don't cause issues
    [_uploader resume];
    XCTAssertFalse([[_uploader valueForKey:@"_isPaused"] boolValue]);
}

@end
