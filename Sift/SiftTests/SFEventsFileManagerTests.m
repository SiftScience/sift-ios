// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFEventsFileManager.h"
#import "SFEventsFileManagerInternal.h"

@interface SFEventsFileManagerTests : XCTestCase

@end

@implementation SFEventsFileManagerTests {
    SFEventsFileManager *manager;
}

- (void)setUp {
    [super setUp];
    NSString *eventsDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    manager = [[SFEventsFileManager alloc] initWithEventsDirName:eventsDirName];
}

- (void)tearDown {
    [manager removeEventsDir];
    [super tearDown];
}

- (void)testRotateCurrentEventsFile {
    [manager createCurrentEventsFileNeedLocking];

    {
        NSArray *fileNames = @[];
        XCTAssert([fileNames isEqualToArray:toFileNames([manager listEventsFilePathsNeedLocking])]);
    }
    
    [manager maybeRotateCurrentEventsFile:YES];

    {
        NSArray *fileNames = @[@"events-1"];
        XCTAssert([fileNames isEqualToArray:toFileNames([manager listEventsFilePathsNeedLocking])]);
    }

    [manager createCurrentEventsFileNeedLocking];

    {
        NSArray *fileNames = @[@"events-1"];
        XCTAssert([fileNames isEqualToArray:toFileNames([manager listEventsFilePathsNeedLocking])]);
    }

    [manager maybeRotateCurrentEventsFile:YES];
    
    {
        NSArray *fileNames = @[@"events-1", @"events-2"];
        XCTAssert([fileNames isEqualToArray:toFileNames([manager listEventsFilePathsNeedLocking])]);
    }

    [manager createCurrentEventsFileNeedLocking];
    
    {
        NSArray *fileNames = @[@"events-1", @"events-2"];
        XCTAssert([fileNames isEqualToArray:toFileNames([manager listEventsFilePathsNeedLocking])]);
    }
}

NSArray *toFileNames(NSArray *paths) {
    NSMutableArray *fileNames = [NSMutableArray arrayWithCapacity:paths.count];
    for (NSString *path in paths) {
        [fileNames addObject:[path lastPathComponent]];
    }
    return fileNames;
}

- (void)testFindNextEventsFilePath {
    [manager createEventsDirNeedLocking];

    {
        NSString *path = [manager findNextEventsFilePathNeedLocking];
        XCTAssertEqualObjects(@"events-1", [path lastPathComponent]);
    }

    XCTAssert([manager.manager createFileAtPath:[manager.eventsDirPath stringByAppendingPathComponent:@"events-1"] contents:nil attributes:nil]);
    
    {
        NSString *path = [manager findNextEventsFilePathNeedLocking];
        XCTAssertEqualObjects(@"events-2", [path lastPathComponent]);
    }

    XCTAssert([manager.manager createFileAtPath:[manager.eventsDirPath stringByAppendingPathComponent:@"events-5"] contents:nil attributes:nil]);
    
    {
        NSString *path = [manager findNextEventsFilePathNeedLocking];
        XCTAssertEqualObjects(@"events-6", [path lastPathComponent]);
    }

    XCTAssert([manager.manager createFileAtPath:[manager.eventsDirPath stringByAppendingPathComponent:@"events"] contents:nil attributes:nil]);
    XCTAssert([manager.manager createFileAtPath:[manager.eventsDirPath stringByAppendingPathComponent:@"events-2"] contents:nil attributes:nil]);
    XCTAssert([manager.manager createFileAtPath:[manager.eventsDirPath stringByAppendingPathComponent:@"not-events-7"] contents:nil attributes:nil]);
    
    {
        NSString *path = [manager findNextEventsFilePathNeedLocking];
        XCTAssertEqualObjects(@"events-6", [path lastPathComponent]);
    }
}

@end
