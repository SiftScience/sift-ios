// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SiftUtils.h"

@interface SiftUtilsTests : XCTestCase

@end

@implementation SiftUtilsTests

- (void)testCamelCaseToSnakeCase {
    XCTAssert([@"hello" isEqualToString:SFCamelCaseToSnakeCase(@"Hello")]);
    XCTAssert([@"hello" isEqualToString:SFCamelCaseToSnakeCase(@"hello")]);
    XCTAssert([@"hello" isEqualToString:SFCamelCaseToSnakeCase(@"HELLO")]);

    XCTAssert([@"hello_world" isEqualToString:SFCamelCaseToSnakeCase(@"HelloWorld")]);
    XCTAssert([@"hello_world" isEqualToString:SFCamelCaseToSnakeCase(@"helloWORLD")]);
    XCTAssert([@"hello_world" isEqualToString:SFCamelCaseToSnakeCase(@"helloWorld")]);
    XCTAssert([@"hello_world" isEqualToString:SFCamelCaseToSnakeCase(@"HELLOWorld")]);

    XCTAssert([@"sf_camel_case_to_snake_case" isEqualToString:SFCamelCaseToSnakeCase(@"SFCamelCaseToSnakeCase")]);

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
