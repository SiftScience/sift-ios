// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SiftCompatibility.h"

#import "SiftHtDictionary.h"

@interface SiftHtDictionaryTests : XCTestCase

@end

@implementation SiftHtDictionaryTests

- (void)testDictEquality {
    SF_GENERICS(NSDictionary, NSString *, Class) *entryTypes = @{
        @"number": NSNumber.class,
        @"string": NSString.class,
        @"array": NSArray.class,
    };

    SiftHtDictionary *d1 = [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
    SiftHtDictionary *d2 = [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
    XCTAssertEqualObjects(d1, d2);

    XCTAssertTrue([d1 setEntry:@"number" value:[NSNumber numberWithBool:NO]]);
    XCTAssertNotEqualObjects(d1, d2);

    XCTAssertTrue([d2 setEntry:@"number" value:@NO]);
    SF_GENERICS(NSArray, NSString *) *data = @[@"a", @"b"];
    XCTAssertTrue([d1 setEntry:@"array" value:data]);
    XCTAssertTrue([d2 setEntry:@"array" value:data]);
    XCTAssertEqualObjects(d1, d2);

    data = @[@"a"];
    XCTAssertTrue([d2 setEntry:@"array" value:data]);
    XCTAssertNotEqualObjects(d1, d2);
}

- (void)testSetEntry {
    SF_GENERICS(NSDictionary, NSString *, Class) *entryTypes = @{
        @"number": NSNumber.class,
    };
    SiftHtDictionary *d = [[SiftHtDictionary alloc] initWithEntryTypes:entryTypes];
    XCTAssertFalse([d setEntry:@"number" value:nil]);
    XCTAssertFalse([d setEntry:@"number" value:[NSNumber numberWithDouble:NAN]]);
    XCTAssertFalse([d setEntry:@"number" value:[NSNumber numberWithDouble:INFINITY]]);
    XCTAssertFalse([d setEntry:@"noSuchKey" value:@YES]);
    XCTAssertFalse([d setEntry:@"number" value:@"string"]);
}

@end
