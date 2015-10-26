// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFMetrics.h"
#import "SFUtil.h"

#import "SFUploader.h"
#import "SFUploader+Private.h"

static NSString * const SFSessionIdentifier = @"com.sift.UploadSession";

static NSString * const SFUploadFileName = @"upload.json";
static NSString * const SFUploadSourcesFileName = @"upload-sources.json";

@implementation SFUploader {
    SFQueueDirs *_queueDirs;
    NSFileManager *_manager;
    NSString *_uploadFilePath;
    NSString *_uploadSourcesFilePath;
    NSURLSession *_session;
    NSURLRequest *_request;
    NSURL *_uploadUrl;
}

- (instancetype)initWithServerUrl:(NSString *)serverUrl rootDirPath:(NSString *)rootDirPath queueDirs:(SFQueueDirs *)queueDirs operationQueue:(NSOperationQueue *)operationQueue config:(NSURLSessionConfiguration *)config {
    self = [super init];
    if (self) {
        _queueDirs = queueDirs;

        _manager = [NSFileManager defaultManager];
        _uploadFilePath = [rootDirPath stringByAppendingPathComponent:SFUploadFileName];
        _uploadSourcesFilePath = [rootDirPath stringByAppendingPathComponent:SFUploadSourcesFileName];

        if (!config) {
            config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:SFSessionIdentifier];
        }
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:operationQueue];

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:serverUrl]];
        request.HTTPMethod = @"POST";
        _request = request;

        _uploadUrl = [NSURL fileURLWithPath:_uploadFilePath isDirectory:NO];
    }
    return self;
}

- (BOOL)upload {
    if ([_manager fileExistsAtPath:_uploadSourcesFilePath]) {
        // TODO(clchiou): If _uploadSourcesFilePath is too old, just overwrite it... (to make progress when prior error happens).
        XXX
        SFDebug(@"An upload is in progress; skip this uplaod request...");
        return YES;
    }

    NSMutableArray *sourceFilePaths = [NSMutableArray new];
    if (![self collectEventsInto:[NSFileHandle fileHandleForWritingAtPath:_uploadFilePath] fromFilePaths:sourceFilePaths]) {
        // TODO(clchiou): Add metrics.
        return NO;
    }

    if (!SFWriteJsonToFile(sourceFilePaths, _uploadSourcesFilePath)) {
        // TODO(clchiou): Add metrics.
        NSError *error;
        if (![_manager removeItemAtPath:_uploadSourcesFilePath error:&error]) {
            SFDebug(@"Could not remove \"%@\" file due to %@", _uploadSourcesFilePath, [error localizedDescription]);
            // TODO(clchiou): Add metrics.
        }
        return NO;
    }

    [[SFMetrics sharedMetrics] count:SFMetricsKeyUploaderUpload];
    [[_session uploadTaskWithRequest:_request fromFile:_uploadUrl] resume];
    return YES;
}

- (BOOL)collectEventsInto:(NSFileHandle *)listRequest fromFilePaths:(NSMutableArray *)sourceFilePaths {
    SFRecordIoToListRequestConverter *converter = [SFRecordIoToListRequestConverter new];
    if (![converter start:listRequest]) {
        return NO;
    }

    BOOL okay = [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *filePaths) {
            for (NSString *filePath in filePaths) {
                if (![converter convert:[NSFileHandle fileHandleForReadingAtPath:filePath]]) {
                    return NO;
                }
            }
            [sourceFilePaths addObjectsFromArray:filePaths];
            return YES;
        }];
    }];
    if (!okay) {
        return NO;
    }

    return [converter end];
}

- (void)removeSourceFiles:(NSSet *)sourceFilePaths {
    [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *filePaths) {
            for (NSString *filePath in filePaths) {
                if ([sourceFilePaths containsObject:filePath]) {
                    NSError *error;
                    if (![manager removeItemAtPath:filePath error:&error]) {
                        // We will upload this file again, resulting in duplicated data in the server...
                        SFDebug(@"Could not remove \"%@\" due to %@", filePath, [error localizedDescription]);
                        // TODO(clchiou): Add metrics.
                    }
                }
            }
            return YES;
        }];
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        SFDebug(@"Could not complete upload due to %@", [error localizedDescription]);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyUploaderNetworkError];
        return;
    }

    // TODO(clchiou): How do we call methods of a subclass in Objective C?
    NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];

    SFDebug(@"POST %@ status %ld", task.response.URL, statusCode);
    if (statusCode == 200) {
        SFDebug(@"Remove uploaded source files");

        NSArray *sourceFilePaths = SFReadJsonFromFile(_uploadSourcesFilePath);
        if (!sourceFilePaths) {
            SFDebug(@"Could not read sources file paths from disk");
            // TODO(clchiou): Add metrics.
            return;
        }

        [self removeSourceFiles:[NSSet setWithArray:sourceFilePaths]];

        NSError *error;
        if (![_manager removeItemAtPath:_uploadSourcesFilePath error:&error]) {
            SFDebug(@"Could not remove source files list");
            // TODO(clchiou): Add metrics.
        }
    }

    /*
    if (_completionHandler) {
        _completionHandler();
    }
     */
}

@end
