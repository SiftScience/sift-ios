// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFUtil.h"
#import "SFEventFileStore.h"
#import "SFEventFileStore+Internal.h"

#import "SFStubHttpProtocol.h"

#import "SFEventFileUploader.h"
#import "SFEventFileUploader+Internal.h"

@interface SFEventFileUploaderTests : XCTestCase

@end

@implementation SFEventFileUploaderTests {
    NSString *_rootDirPath;
    SFEventFileManager *_manager;
    SFEventFileUploader *_uploader;
}

- (void)setUp {
    [super setUp];

    int testId = arc4random_uniform(1 << 20);
    _rootDirPath = [SFCacheDirPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"testdata-%07d", testId]];

    NSOperationQueue *queue = [NSOperationQueue new];

    _manager = [[SFEventFileManager alloc] initWithRootDir:_rootDirPath];

    _uploader = SFStubHttpProtocolMakeUploader(queue, _manager, _rootDirPath);
}

- (void)tearDown {
    NSError *error;
    XCTAssert([[NSFileManager defaultManager] removeItemAtPath:_rootDirPath error:&error], @"Could not remove \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
    [super tearDown];
}

- (void)testSaveAndLoadTasks {
    XCTAssertEqual(0, [_uploader loadTasks].count);
    NSDictionary *dicts[] = {
        @{@"key1": @"value1"},
        @{@"key1": @"value1", @"key2": @"value2"},
        @{@"key1": @"value1", @"key2": @"value2", @"key3": @"value3"},
    };
    for (int i = 0; i < sizeof(dicts) / sizeof(dicts[0]); i++) {
        XCTAssert([_uploader saveTasks:dicts[i]]);
        XCTAssertEqualObjects(dicts[i], [_uploader loadTasks]);
    }
}

- (void)testUpload {
    const int NUM_UPLOAD_TASKS = 30;

    XCTestExpectation *expectation = [self expectationWithDescription:@"Wait for upload tasks completion"];
    NSMutableArray *completed = [[NSMutableArray alloc] initWithObjects:@0, nil];
    _uploader.completionHandler = ^{
        NSNumber *count = completed[0];
        int newCount = count.intValue + 1;
        completed[0] = [NSNumber numberWithInt:newCount];
        if (newCount == NUM_UPLOAD_TASKS) {
            [expectation fulfill];
        }
    };

    XCTAssert([_manager addEventStore:@"id-1"]);
    XCTAssert([_manager addEventStore:@"id-2"]);

    XCTAssertEqualObjects(@[], [[[_uploader loadTasks] allValues] sortedArrayUsingSelector:@selector(compare:)]);

    NSMutableArray *expect = [NSMutableArray new];
    [_manager accessEventStore:@"id-1" block:^BOOL (SFEventFileStore *store) {
        // Create event files...
        for (int i = 0; i < NUM_UPLOAD_TASKS; i++) {
            XCTAssertNotNil([store currentEventFile]);
            XCTAssert([store rotateCurrentEventFile]);
        }
        [store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *currentEventFilePaths) {
            [expect addObjectsFromArray:currentEventFilePaths];
            return YES;
        }];
        // Upload them...
        [store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *eventFilePaths) {
            XCTAssertEqual(NUM_UPLOAD_TASKS, eventFilePaths.count);
            XCTAssertEqualObjects(expect, eventFilePaths);
            for (NSString *path in eventFilePaths) {
                [_uploader upload:path identifier:@"id-1"];
            }
            return YES;
        }];
        return YES;
    }];
    
    [_manager accessEventStore:@"id-2" block:^BOOL (SFEventFileStore *store) {
        [store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *eventFilePaths) {
            XCTAssertEqualObjects(@[], eventFilePaths);
            return YES;
        }];
        return YES;
    }];

    XCTAssertEqual(expect.count, _uploader.tasks.count);
    NSMutableArray *actual = [NSMutableArray new];
    for (NSArray *blob in _uploader.tasks.allValues) {
        XCTAssertEqualObjects(@"id-1", blob[0]);
        [actual addObject:blob[1]];
    }
    XCTAssertEqualObjects([expect sortedArrayUsingSelector:@selector(compare:)], [actual sortedArrayUsingSelector:@selector(compare:)]);

    // Wait until all upload tasks are completed...
    [self waitForExpectationsWithTimeout:5.0 handler:nil];

    // All events-id1/events-* files should be removed.
    [_manager accessEventStore:@"id-1" block:^BOOL (SFEventFileStore *store) {
        [store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *eventFilePaths) {
            XCTAssertEqualObjects(@[], eventFilePaths);
            return YES;
        }];
        return YES;
    }];
}

@end
