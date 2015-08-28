//
//  SiftTests.m
//  SiftTests
//
//  Created by Che-Liang Chiou on 8/25/15.
//  Copyright © 2015 Sift Science. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "Sift.h"

@interface SiftTests : XCTestCase

@end

@implementation SiftTests

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testTrack {
    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for HTTP requests..."];
    
    Sift *sift = [[Sift alloc] initWithIdentifier:@"com.sift.test.BeaconBackgroundSession"];
    // TODO: set to a local server
    //sift.tracker = @"http://my-local-server";

    sift.completionHandler = ^(NSURLSession *session, NSURLSessionTask *task, NSError *error) {
        [expectation fulfill];
    };

    [sift track:@"http://www.example.com/index.html" title:@"Hello world"];
    
    [self waitForExpectationsWithTimeout:10.0 handler:nil];
}

- (void)testTrackerUrl {
    NSString *trackerUrl = [Sift track:@"http://www.example.com/page" title:@"Page title" tracker:@"https://b.siftscience.com" referer:@"http://www.example.com/"];
    XCTAssertEqualObjects(@"https://b.siftscience.com/i.gif?rf=http://www.example.com/&t=Page%20title&u=http://www.example.com/page&z=z", trackerUrl);
}

@end
