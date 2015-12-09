// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFEvent+Utils.h"
#import "SFMetrics.h"
#import "SFUtils.h"

#import "SFUploader.h"
#import "SFUploader+Private.h"

static NSString * const SFSessionIdentifier = @"com.sift.UploadSession";
static NSString * const SFRequestIdHeader = @"X-REQUEST-ID";

/**
 * If a state file is older than this value, we should treat its
 * respective upload has failed and remove it.
 */
static const NSTimeInterval SFRemoveStateFileOlderThan = 300;  // 5 minutes.

static NSString *SFRequestBodyFilePath(NSString *stateDirPath, uint32_t requestId);
static NSString *SFSourceListFilePath(NSString *stateDirPath, uint32_t requestId);

@implementation SFUploader {
    SFQueueDirs *_queueDirs;
    NSURLSession *_session;
    NSString *_rootDirPath;
    // For testing.
    CompletionHandlerType _completionHandler;
}

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath queueDirs:(SFQueueDirs *)queueDirs operationQueue:(NSOperationQueue *)operationQueue config:(NSURLSessionConfiguration *)config {
    self = [super init];
    if (self) {
        _queueDirs = queueDirs;

        _rootDirPath = rootDirPath;
        if (!SFTouchDirPath(_rootDirPath)) {
            self = nil;
            return nil;
        }

        if (!config) {
            config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:SFSessionIdentifier];
        }
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:operationQueue];

        _completionHandler = nil;
    }
    return self;
}

- (void)cleanup {
    @synchronized(self) {
        NSArray *paths = SFListDir(_rootDirPath);
        if (!paths || paths.count == 0) {
            return;
        }
        for (NSString *path in paths) {
            NSTimeInterval sinceNow;
            if (SFFileCreationDate(path, &sinceNow) && sinceNow > SFRemoveStateFileOlderThan) {
                SFRemoveFile(path);
            }
        }
    }
}

- (void)removeData {
    @synchronized(self) {
        SFRemoveFilesInDir(_rootDirPath);
    }
}

- (BOOL)upload:(NSString *)serverUrlFormat accountId:(NSString *)accountId beaconKey:(NSString *)beaconKey force:(BOOL)force {
    @synchronized(self) {
        if (!force && !SFIsDirEmpty(_rootDirPath)) {
            SFDebug(@"An upload is in progress; skip this uplaod request...");
            return YES;
        }

        uint32_t requestId = arc4random();


        NSString *requestBodyFilePath = SFRequestBodyFilePath(_rootDirPath, requestId);
        NSString *sourceListFilePath = SFSourceListFilePath(_rootDirPath, requestId);
        BOOL keepFiles = NO;

        @try {
            if (!SFTouchFilePath(requestBodyFilePath) || !SFTouchFilePath(sourceListFilePath)) {
                return NO;
            }

            NSMutableArray *sourceFilePaths = [NSMutableArray new];
            if (![self collectEventsInto:[NSFileHandle fileHandleForWritingAtPath:requestBodyFilePath] fromFilePaths:sourceFilePaths]) {
                return NO;
            }
            if (sourceFilePaths.count == 0) {
                SFDebug(@"Nothing to upload");
                return YES;
            }
#ifndef NDEBUG
            {
                NSError *error;
                NSString *listRequestText = [NSString stringWithContentsOfFile:requestBodyFilePath encoding:NSASCIIStringEncoding error:&error];
                if (listRequestText) {
                    SFDebug(@"Upload list request:\n%@", listRequestText);
                } else {
                    SFDebug(@"Could not read \"%@\" due to %@", requestBodyFilePath, [error localizedDescription]);
                }
            }
#endif

            if (!SFWriteJsonToFile(sourceFilePaths, sourceListFilePath)) {
                return NO;
            }

            NSURL *serverUrl = [NSURL URLWithString:[NSString stringWithFormat:serverUrlFormat, accountId]];
            SFDebug(@"serverUrl: %@", serverUrl);
            if(!serverUrl) {
                SFDebug(@"Could not construct server URL");
                SFDebug(@"serverUrlFormat: %@", serverUrlFormat);
                SFDebug(@"accountId: %@", accountId);
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumMiscErrors];
                return NO;
            }

            NSString *encodedBeaconKey = [[beaconKey dataUsingEncoding:NSASCIIStringEncoding] base64EncodedStringWithOptions:0];

            NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:serverUrl];
            [request setHTTPMethod:@"PUT"];
            [request setValue:[@"Basic " stringByAppendingString:encodedBeaconKey] forHTTPHeaderField:@"Authorization"];
            [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
            [request setValue:[NSString stringWithFormat:@"%u", requestId] forHTTPHeaderField:SFRequestIdHeader];
            SFDebug(@"request: %@", request);

            NSURL *requestBodyFileUrl = [NSURL fileURLWithPath:requestBodyFilePath isDirectory:NO];
            SFDebug(@"requestBodyFileUrl: %@", requestBodyFileUrl);

            [[_session uploadTaskWithRequest:request fromFile:requestBodyFileUrl] resume];
            [[SFMetrics sharedMetrics] count:SFMetricsKeyNumUploads];
            keepFiles = YES;

            return YES;
        }
        @finally {
            if (!keepFiles) {
                for (NSString *path in @[requestBodyFilePath, sourceListFilePath]) {
                    SFRemoveFile(path);
                }
            }
        }
    }
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
            return [rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSArray *filePaths) {
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
        return [rotatedFiles accessNonCurrentFilesWithBlock:^BOOL (NSArray *filePaths) {
            for (NSString *filePath in filePaths) {
                if ([sourceFilePaths containsObject:filePath]) {
                    // If we failed to remove it, we will upload this file again, resulting in duplicated data in the server...
                    SFRemoveFile(filePath);
                }
            }
            return YES;
        }];
    }];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    @synchronized(self) {
        uint32_t requestId = (uint32_t)[task.originalRequest valueForHTTPHeaderField:SFRequestIdHeader].integerValue;
        NSString *requestBodyFilePath = SFRequestBodyFilePath(_rootDirPath, requestId);
        NSString *sourceListFilePath = SFSourceListFilePath(_rootDirPath, requestId);

        @try {
            if (error) {
                SFDebug(@"Could not complete upload due to %@", [error localizedDescription]);
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumNetworkErrors];
                return;
            }

            NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
            SFDebug(@"PUT %@ status %ld", task.response.URL, (long)statusCode);
            if (statusCode == 200) {
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumUploadsSucceeded];
                NSArray *sourceFilePaths = SFReadJsonFromFile(SFSourceListFilePath(_rootDirPath, requestId));
                if (!sourceFilePaths) {
                    SFDebug(@"Could not read sources file paths from disk");
                    return;
                }
                [self removeSourceFiles:[NSSet setWithArray:sourceFilePaths]];
            } else {
                [[SFMetrics sharedMetrics] count:SFMetricsKeyNumHttpErrors];
            }
        }
        @finally {
            for (NSString *path in @[requestBodyFilePath, sourceListFilePath]) {
                SFRemoveFile(path);
            }
        }
        // For testing.
        if (_completionHandler) {
            _completionHandler();
        }
    }
}

@end

static NSString *SFRequestBodyFilePath(NSString *stateDirPath, uint32_t requestId) {
    return [stateDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"body-%08x.json", requestId]];
}

static NSString *SFSourceListFilePath(NSString *stateDirPath, uint32_t requestId) {
    return [stateDirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"srcs-%08x.json", requestId]];
}
