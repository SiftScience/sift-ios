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

static const NSTimeInterval SFUploadTimeout = 60;  // 1 minute.

@implementation SFUploader {
    SFQueueDirs *_queueDirs;
    NSFileManager *_manager;
    NSString *_uploadFilePath;
    NSString *_uploadSourcesFilePath;
    NSURLSession *_session;
    NSURL *_uploadUrl;
    // For testing.
    CompletionHandlerType _completionHandler;
}

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath queueDirs:(SFQueueDirs *)queueDirs operationQueue:(NSOperationQueue *)operationQueue config:(NSURLSessionConfiguration *)config {
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

        _uploadUrl = [NSURL fileURLWithPath:_uploadFilePath isDirectory:NO];

        _completionHandler = nil;
    }
    return self;
}

- (BOOL)upload:(NSString *)serverUrlFormat accountId:(NSString *)accountId beaconKey:(NSString *)beaconKey {
    if ([_manager fileExistsAtPath:_uploadSourcesFilePath]) {
        BOOL shouldSkip = true;
        NSError *error;
        NSDictionary *attributes = [_manager attributesOfItemAtPath:_uploadSourcesFilePath error:&error];
        if (!attributes) {
            SFDebug(@"Could not get attributes of \"%@\" due to %@", _uploadSourcesFilePath, [error localizedDescription]);
        } else {
            NSTimeInterval sinceNow = -[[attributes fileModificationDate] timeIntervalSinceNow];
            if (sinceNow > SFUploadTimeout) {
                SFDebug(@"\"%@\" is too old and we should probably overwrite it...", _uploadSourcesFilePath);
                shouldSkip = false;
            }
        }
        if (shouldSkip) {
            SFDebug(@"An upload is in progress; skip this uplaod request...");
            return YES;
        }
    }

    if (!SFTouchFilePath(_uploadFilePath)) {
        SFDebug(@"Could not touch \"%@\"", _uploadFilePath);
        return NO;
    }
    NSMutableArray *sourceFilePaths = [NSMutableArray new];
    if (![self collectEventsInto:[NSFileHandle fileHandleForWritingAtPath:_uploadFilePath] fromFilePaths:sourceFilePaths]) {
        // TODO(clchiou): Add metrics.
        return NO;
    }
#ifndef NDEBUG
    {
        NSError *error;
        NSString *listRequestText = [NSString stringWithContentsOfFile:_uploadFilePath encoding:NSASCIIStringEncoding error:&error];
        if (listRequestText) {
            SFDebug(@"Upload list request:\n>>>\n%@\n<<<", listRequestText);
        } else {
            SFDebug(@"Could not read \"%@\" due to %@", _uploadFilePath, [error localizedDescription]);
        }
    }
#endif

    if (!SFTouchFilePath(_uploadSourcesFilePath)) {
        SFDebug(@"Could not touch \"%@\"", _uploadSourcesFilePath);
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

    NSString *url = [NSString stringWithFormat:serverUrlFormat, accountId];
    NSString *encodedBeaconKey = [[beaconKey dataUsingEncoding:NSASCIIStringEncoding] base64EncodedStringWithOptions:0];
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:url]];
    [request setHTTPMethod:@"PUT"];
    [request setValue:[@"Basic " stringByAppendingString:encodedBeaconKey] forHTTPHeaderField:@"Authorization"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

    [[SFMetrics sharedMetrics] count:SFMetricsKeyUploaderUpload];
    [[_session uploadTaskWithRequest:request fromFile:_uploadUrl] resume];
    return YES;
}

- (BOOL)collectEventsInto:(NSFileHandle *)listRequest fromFilePaths:(NSMutableArray *)sourceFilePaths {
    SFRecordIoToListRequestConverter *converter = [SFRecordIoToListRequestConverter new];
    if (![converter start:listRequest]) {
        return NO;
    }

    if (_queueDirs.numDirs == 0) {
        SFDebug(@"No queue dirs to collect from (probably a bug?)");
    } else {
        BOOL okay = [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
            return [rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *filePaths) {
                for (NSString *filePath in filePaths) {
                    SFDebug(@"Collect events from \"%@\"", filePath);
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
    }

    return [converter end];
}

- (void)removeSourceFiles:(NSSet *)sourceFilePaths {
    [_queueDirs useDirsWithBlock:^BOOL (SFRotatedFiles *rotatedFiles) {
        return [rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *filePaths) {
            for (NSString *filePath in filePaths) {
                if ([sourceFilePaths containsObject:filePath]) {
                    SFDebug(@"Remove \"%@\"...", filePath);
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
    @try {
        if (error) {
            SFDebug(@"Could not complete upload due to %@", [error localizedDescription]);
            [[SFMetrics sharedMetrics] count:SFMetricsKeyUploaderNetworkError];
            return;
        }

        // TODO(clchiou): How do we call methods of a subclass in Objective C?
        NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];

        SFDebug(@"PUT %@ status %ld", task.response.URL, statusCode);
        if (statusCode == 200) {
            NSArray *sourceFilePaths = SFReadJsonFromFile(_uploadSourcesFilePath);
            if (!sourceFilePaths) {
                SFDebug(@"Could not read sources file paths from disk");
                // TODO(clchiou): Add metrics.
                return;
            }
            [self removeSourceFiles:[NSSet setWithArray:sourceFilePaths]];
        }
    }
    @finally {
        for (NSString *path in @[_uploadFilePath, _uploadSourcesFilePath]) {
            SFDebug(@"Remove \"%@\"...", path);
            NSError *error;
            if (![_manager removeItemAtPath:path error:&error]) {
                SFDebug(@"Could not remove \"%@\" due to %@", path, [error localizedDescription]);
                // TODO(clchiou): Add metrics.
            }
        }
    }
    // For testing.
    if (_completionHandler) {
        _completionHandler();
    }
}

@end
