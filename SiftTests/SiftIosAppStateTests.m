// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

@import CoreLocation;

#import "SiftDebug.h"

#import "SiftIosAppState.h"

@interface SiftIosAppStateTests : XCTestCase

@end

@implementation SiftIosAppStateTests

- (void)testCollect {
    SiftHtDictionary *actual = SFCollectIosAppState([CLLocationManager new], nil);
    SF_DEBUG(@"Collect app state: %@", actual.entries);
    XCTAssertNotNil(actual);
}

@end
