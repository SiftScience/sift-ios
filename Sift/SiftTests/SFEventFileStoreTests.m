// Copyright © 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFUtil.h"

#import "SFEventFileStore.h"
#import "SFEventFileStore+Internal.h"

@interface SFEventFileStoreTests : XCTestCase

@end

@implementation SFEventFileStoreTests {
    NSString *_eventDirName;
    NSString *_eventDirPath;
    SFEventFileStore *_store;
}

- (void)setUp {
    [super setUp];
    _eventDirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _eventDirPath = [SFCacheDirPath() stringByAppendingPathComponent:_eventDirName];
    _store = [[SFEventFileStore alloc] initWithEventDirPath:_eventDirPath];
}

- (void)tearDown {
    [_store removeEventDir];
    [super tearDown];
}

- (void)testWriteCurrentEventFileWithBlock {
    XCTAssert(![self exist:@"events"]);

    [_store writeCurrentEventFileWithBlock:^BOOL (NSFileHandle *handle){
        [handle writeData:[NSData dataWithBytes:"hello" length:5]];
        return YES;
    }];
    XCTAssert([self exist:@"events"]);

    NSString *data = [NSString stringWithContentsOfFile:[_eventDirPath stringByAppendingPathComponent:@"events"] usedEncoding:nil error:nil];
    XCTAssertEqualObjects(@"hello", data);
}

- (void)testAccessEventFilesWithBlock {
    // Add garbage.
    [self touch:@"events"];
    [self touch:@"events0"];
    [self touch:@"not-events-1"];

    NSMutableArray *paths = [NSMutableArray new];
    [_store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *eventFilePaths){
        XCTAssertEqualObjects(paths, eventFilePaths);
        return YES;
    }];

    for (int i = 0; i < 30; i++) {
        [paths addObject:[self touch:[NSString stringWithFormat:@"events-%d", i]]];
        [_store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *eventFilePaths){
            XCTAssertEqualObjects(paths, eventFilePaths);
            return YES;
        }];
    }
}

- (void)testRotateCurrentEventFile {
    XCTAssert(![self exist:@"events"]);
    XCTAssertEqualObjects(@[], [_store eventFilePaths]);

    XCTAssert(![self exist:@"events"]);
    XCTAssert([_store rotateCurrentEventFile]);
    XCTAssertEqualObjects(@[], [_store eventFilePaths]);

    // Add garbage.
    [self touch:@"events0"];
    [self touch:@"not-events-1"];

    XCTAssert(![self exist:@"events"]);
    XCTAssert([_store rotateCurrentEventFile]);
    XCTAssertEqualObjects(@[], [_store eventFilePaths]);

    NSMutableArray *paths = [NSMutableArray new];
    for (int i = 0; i < 30; i++) {
        XCTAssertNotNil([_store currentEventFile]);
        XCTAssert([self exist:@"events"]);

        XCTAssert([_store rotateCurrentEventFile]);
        XCTAssert(![self exist:@"events"]);

        [paths addObject:[_eventDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"events-%d", i]]];
        XCTAssertEqualObjects(paths, [_store eventFilePaths]);
    }
}

- (void)testCurrentEventFile {
    XCTAssert(![self exist:@"events"]);

    XCTAssertNotNil([_store currentEventFile]);
    XCTAssert([self exist:@"events"]);

    [_store removeCurrentEventFile];
    XCTAssert(![self exist:@"events"]);
}

- (void)testEventFilePaths {
    XCTAssertEqualObjects(@[], [_store eventFilePaths]);

    // Add garbage.
    [self touch:@"events"];
    [self touch:@"events0"];
    [self touch:@"not-events-1"];
    XCTAssertEqualObjects(@[], [_store eventFilePaths]);

    NSMutableArray *paths = [NSMutableArray new];
    for (int i = 0; i < 30; i++) {
        [paths addObject:[self touch:[NSString stringWithFormat:@"events-%d", i]]];
        XCTAssertEqualObjects(paths, [_store eventFilePaths]);
    }
}

- (void)testEventFileIndex {
    XCTAssertEqual(-1, [_store eventFileIndex:@"events"]);
    XCTAssertEqual(-1, [_store eventFileIndex:@"events0"]);
    XCTAssertEqual(-1, [_store eventFileIndex:@"not-events-1"]);

    XCTAssertEqual(0, [_store eventFileIndex:@"events-0"]);
    XCTAssertEqual(1, [_store eventFileIndex:@"events-1"]);
    XCTAssertEqual(2, [_store eventFileIndex:@"events-2"]);

    XCTAssertEqual(10, [_store eventFileIndex:@"events-10"]);
    XCTAssertEqual(11, [_store eventFileIndex:@"events-11"]);
    XCTAssertEqual(12, [_store eventFileIndex:@"events-12"]);
}

- (BOOL)exist:(NSString *)fileName {
    NSString *path = [_eventDirPath stringByAppendingPathComponent:fileName];
    return [[NSFileManager defaultManager] isWritableFileAtPath:path];
}

- (NSString *)touch:(NSString *)fileName {
    NSString *path = [_eventDirPath stringByAppendingPathComponent:fileName];
    XCTAssert([[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]);
    return path;
}

@end
