// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "Sift.h"
#import "SiftInternal.h"

@interface SiftTests : XCTestCase

@end

@implementation SiftTests {
    Sift *sift;
}

- (void)setUp {
    [super setUp];
    NSString *testName = [NSString stringWithFormat:@"SiftTests-%07d", arc4random_uniform(1 << 20)];
    sift = [[Sift alloc] initWithIdentifier:testName manager:[[SFEventsFileManager alloc] initWithEventsDirName:testName]];
}

- (void)tearDown {
    [sift.manager removeEventsDir];
    [super tearDown];
}

- (void)testTracker {
    XCTAssert([@"https://b.siftscience.com/" isEqualToString:sift.tracker]);
    
    sift.tracker = @"http://127.0.0.1:8000/";
    XCTAssert([@"http://127.0.0.1:8000/" isEqualToString:sift.tracker]);
}

- (void)testWriteToCurrentEventsFile {
    NSDictionary *testData[] = {
        @{@"key1": @"value1", @"key2": @"value2"},
        @{@"key": @"value"},
        @{},
    };
    for (int i = 0; i < sizeof(testData) / sizeof(testData[0]); i++) {
        [sift writeToCurrentEventsFile:createEvent(testData[i])];
    }

    [sift.manager maybeRotateCurrentEventsFile:YES];
    [sift.manager processEventsFiles:^(NSFileManager *manager, NSArray *paths) {
        XCTAssertEqual(1, paths.count);

        NSData *data = [[NSData alloc] initWithContentsOfFile:paths[0]];

        NSDictionary *expect[] = {
            @{@"key1": @"value1", @"key2": @"value2"},
            @{@"key": @"value"},
            @{},
        };
        NSUInteger location = 0;
        for (int i = 0; i < sizeof(expect) / sizeof(expect[0]); i++) {
            NSDictionary *event = readEvent(data, &location);
            XCTAssertTrue([expect[i] isEqualToDictionary:event]);
        }
        // We have read the whole data.
        XCTAssertEqual(location, data.length);
    }];
}

- (void)testEvent {
    XCTestExpectation *expectPersisted = [self expectationWithDescription:@"Wait for event written to disk"];
    sift.eventPersistedCallback = ^(NSFileHandle *currentEventsFile, NSData *event) {
        [expectPersisted fulfill];
    };
    [sift event:@{@"key": @"value"}];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];

    [sift.manager maybeRotateCurrentEventsFile:YES];
    
    XCTestExpectation *expectUpload = [self expectationWithDescription:@"Wait for HTTP response"];
    sift.uploadTaskCompletionCallback = ^(NSURLSession *session, NSURLSessionTask *task, NSError *error){
        [expectUpload fulfill];
    };
    [sift uploadEventsFiles];
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
    
    // TODO(clchiou): Check events file was (or was not) removed.
}

@end
