// Copyright (c) 2015 Sift Science. All rights reserved.

#import <XCTest/XCTest.h>

#import "SFUtils.h"

#import "SFRotatedFiles.h"
#import "SFRotatedFiles+Private.h"

@interface SFRotatedFilesTests : XCTestCase

@end

@implementation SFRotatedFilesTests {
    NSString *_dirName;
    NSString *_dirPath;
    SFRotatedFiles *_rotatedFiles;
}

- (void)setUp {
    [super setUp];
    _dirName = [NSString stringWithFormat:@"testdata-%07d", arc4random_uniform(1 << 20)];
    _dirPath = [SFCacheDirPath() stringByAppendingPathComponent:_dirName];
    _rotatedFiles = [[SFRotatedFiles alloc] initWithDirPath:_dirPath];
}

- (void)tearDown {
    [_rotatedFiles removeDir];
    [super tearDown];
}

- (void)testWriteCurrentFileWithBlock {
    XCTAssert(![self exist:@"data"]);

    [_rotatedFiles writeCurrentFileWithBlock:^BOOL (NSFileHandle *handle){
        [handle writeData:[NSData dataWithBytes:"hello" length:5]];
        return YES;
    }];
    XCTAssert([self exist:@"data"]);

    NSString *data = [NSString stringWithContentsOfFile:[_dirPath stringByAppendingPathComponent:@"data"] usedEncoding:nil error:nil];
    XCTAssertEqualObjects(@"hello", data);
}

- (void)testAccessNonCurrentFilesWithBlock {
    // Add garbage.
    [self touch:@"data"];
    [self touch:@"data0"];
    [self touch:@"not-data-1"];

    NSMutableArray *paths = [NSMutableArray new];
    [_rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSArray *filePaths){
        XCTAssertEqualObjects(paths, filePaths);
        return YES;
    }];

    for (int i = 0; i < 30; i++) {
        [paths addObject:[self touch:[NSString stringWithFormat:@"data-%d", i]]];
        [_rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSArray *filePaths){
            XCTAssertEqualObjects(paths, filePaths);
            return YES;
        }];
    }
}

- (void)testRotateCurrentFile {
    XCTAssert(![self exist:@"data"]);
    XCTAssertEqualObjects(@[], [_rotatedFiles filePaths]);

    XCTAssert(![self exist:@"data"]);
    XCTAssert([_rotatedFiles rotateFile]);
    XCTAssertEqualObjects(@[], [_rotatedFiles filePaths]);

    // Add garbage.
    [self touch:@"data0"];
    [self touch:@"not-data-1"];

    XCTAssert(![self exist:@"data"]);
    XCTAssert([_rotatedFiles rotateFile]);
    XCTAssertEqualObjects(@[], [_rotatedFiles filePaths]);

    NSMutableArray *paths = [NSMutableArray new];
    for (int i = 0; i < 30; i++) {
        XCTAssertNotNil([_rotatedFiles currentFile]);
        XCTAssert([self exist:@"data"]);

        XCTAssert([_rotatedFiles rotateFile]);
        XCTAssert(![self exist:@"data"]);

        [paths addObject:[_dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"data-%d", i]]];
        XCTAssertEqualObjects(paths, [_rotatedFiles filePaths]);
    }
}

- (void)testCurrentFile {
    XCTAssert(![self exist:@"data"]);

    XCTAssertNotNil([_rotatedFiles currentFile]);
    XCTAssert([self exist:@"data"]);

    [_rotatedFiles removeCurrentFile];
    XCTAssert(![self exist:@"data"]);
}

- (void)testFilePaths {
    XCTAssertEqualObjects(@[], [_rotatedFiles filePaths]);

    // Add garbage.
    [self touch:@"data"];
    [self touch:@"data0"];
    [self touch:@"not-data-1"];
    XCTAssertEqualObjects(@[], [_rotatedFiles filePaths]);

    NSMutableArray *paths = [NSMutableArray new];
    for (int i = 0; i < 30; i++) {
        [paths addObject:[self touch:[NSString stringWithFormat:@"data-%d", i]]];
        XCTAssertEqualObjects(paths, [_rotatedFiles filePaths]);
    }
}

- (void)testFileIndex {
    XCTAssertEqual(-1, [_rotatedFiles fileIndex:@"data"]);
    XCTAssertEqual(-1, [_rotatedFiles fileIndex:@"data0"]);
    XCTAssertEqual(-1, [_rotatedFiles fileIndex:@"not-data-1"]);

    XCTAssertEqual(0, [_rotatedFiles fileIndex:@"data-0"]);
    XCTAssertEqual(1, [_rotatedFiles fileIndex:@"data-1"]);
    XCTAssertEqual(2, [_rotatedFiles fileIndex:@"data-2"]);

    XCTAssertEqual(10, [_rotatedFiles fileIndex:@"data-10"]);
    XCTAssertEqual(11, [_rotatedFiles fileIndex:@"data-11"]);
    XCTAssertEqual(12, [_rotatedFiles fileIndex:@"data-12"]);
}

- (BOOL)exist:(NSString *)fileName {
    NSString *path = [_dirPath stringByAppendingPathComponent:fileName];
    return [[NSFileManager defaultManager] isWritableFileAtPath:path];
}

- (NSString *)touch:(NSString *)fileName {
    NSString *path = [_dirPath stringByAppendingPathComponent:fileName];
    XCTAssert([[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil]);
    return path;
}

@end
