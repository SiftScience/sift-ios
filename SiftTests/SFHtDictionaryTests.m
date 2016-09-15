// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

#import "SFHTDictionary.h"

@interface SFHtDictionaryTests : XCTestCase

@end

@implementation SFHtDictionaryTests

- (void)testDictEquality {
    NSDictionary<NSString *, Class> *entryTypes = @{
        @"number": NSNumber.class,
        @"string": NSString.class,
        @"array": NSArray.class,
    };

    SFHtDictionary *d1 = [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
    SFHtDictionary *d2 = [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
    XCTAssertEqualObjects(d1, d2);

    XCTAssertTrue([d1 setEntry:@"number" value:[NSNumber numberWithBool:NO]]);
    XCTAssertNotEqualObjects(d1, d2);

    XCTAssertTrue([d2 setEntry:@"number" value:@NO]);
    NSArray<NSString *> *data = @[@"a", @"b"];
    XCTAssertTrue([d1 setEntry:@"array" value:data]);
    XCTAssertTrue([d2 setEntry:@"array" value:data]);
    XCTAssertEqualObjects(d1, d2);

    data = @[@"a"];
    XCTAssertTrue([d2 setEntry:@"array" value:data]);
    XCTAssertNotEqualObjects(d1, d2);
}

- (void)testSetEntry {
    NSDictionary<NSString *, Class> *entryTypes = @{
        @"number": NSNumber.class,
    };
    SFHtDictionary *d = [[SFHtDictionary alloc] initWithEntryTypes:entryTypes];
    XCTAssertFalse([d setEntry:@"number" value:nil]);
    XCTAssertFalse([d setEntry:@"noSuchKey" value:@YES]);
    XCTAssertFalse([d setEntry:@"number" value:@"string"]);
}

@end
