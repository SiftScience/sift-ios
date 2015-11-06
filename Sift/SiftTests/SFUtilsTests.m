// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFUtils.h"

@interface SFUtilsTests : XCTestCase

@end

@implementation SFUtilsTests

- (void)testCamelCaseToSnakeCase {
    XCTAssert([@"hello" isEqualToString:SFCamelCaseToSnakeCase(@"Hello")]);
    XCTAssert([@"hello" isEqualToString:SFCamelCaseToSnakeCase(@"hello")]);

    XCTAssert([@"hello_world" isEqualToString:SFCamelCaseToSnakeCase(@"HelloWorld")]);
    XCTAssert([@"hello_world" isEqualToString:SFCamelCaseToSnakeCase(@"helloWorld")]);

    XCTAssert([@"h_e_l_l_o_w_o_r_l_d" isEqualToString:SFCamelCaseToSnakeCase(@"HELLOWORLD")]);

    // Test arbitrary long string.
    NSMutableString *testdata = [NSMutableString new];
    NSMutableString *expect = [NSMutableString new];
    for (int i = 0; i < 1024; i++) {
        [testdata appendString:@"HelloWorld"];
        if (i > 0) {
            [expect appendString:@"_"];
        }
        [expect appendString:@"hello_world"];
    }
    XCTAssert([expect isEqualToString:SFCamelCaseToSnakeCase(testdata)]);
}

@end
