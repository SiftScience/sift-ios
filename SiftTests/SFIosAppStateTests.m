// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

@import CoreLocation;

#import "SFDebug.h"

#import "SFIosAppState.h"

@interface SFIosAppStateTests : XCTestCase

@end

@implementation SFIosAppStateTests

- (void)testCollect {
    SFHtDictionary *actual = SFCollectIosAppState([CLLocationManager new]);
    SF_DEBUG(@"Collect app state: %@", actual.entries);
    XCTAssertNotNil(actual);
}

@end
