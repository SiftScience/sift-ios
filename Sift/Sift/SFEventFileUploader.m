// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFMetrics.h"
#import "SFUtil.h"

#import "SFEventFileUploader.h"
#import "SFEventFileUploader+Internal.h"

static NSString * const SFSessionIdentifier = @"com.sift.UploadSession";

static NSString * const SFTrackerUrl = @"https://b.siftscience.com/";

static NSString * const SFTaskFileName = @"tasks";

@implementation SFEventFileUploader {
    dispatch_queue_t _serialQueue;

    NSURLSession *_session;

    SFEventFileManager *_manager;

    NSString *_taskFilePath;
    NSMutableDictionary *_tasks;

    NSURLRequest *_request;

    // For testing.
    CompletionHandlerType _completionHandler;
}

- (instancetype)initWithQueue:(NSOperationQueue *)queue
            manager:(SFEventFileManager *)manager
        rootDirPath:(NSString *)rootDirPath
          serverUrl:(NSString *)serverUrl {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:SFSessionIdentifier];
    NSString *taskFilePath = [rootDirPath stringByAppendingPathComponent:SFTaskFileName];
    return [self initWithQueue:queue manager:manager config:config serverUrl:(serverUrl ?: SFTrackerUrl) taskFilePath:taskFilePath];
}

- (instancetype)initWithQueue:(NSOperationQueue *)queue
            manager:(SFEventFileManager *)manager
             config:(NSURLSessionConfiguration *)config
          serverUrl:(NSString *)serverUrl
       taskFilePath:(NSString *)taskFilePath {
    self = [super init];
    if (self) {
        _serialQueue = dispatch_queue_create("SFEventFileUploader.serialQueue", DISPATCH_QUEUE_SERIAL);

        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:queue];

        _manager = manager;

        _taskFilePath = taskFilePath;
        _tasks = [self loadTasks];  // TODO(clchiou): What if a task entry "sticks" due to errors?

        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:serverUrl]];
        request.HTTPMethod = @"POST";
        _request = request;

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(applicationWillTerminate:) name:UIApplicationWillTerminateNotification object:nil];

        _completionHandler = nil;
    }
    return self;
}

- (NSMutableDictionary *)loadTasks {
    NSMutableDictionary *tasks = [NSKeyedUnarchiver unarchiveObjectWithFile:_taskFilePath];
    if (!tasks) {
        tasks = [NSMutableDictionary new];
    }
    return tasks;
}

- (BOOL)saveTasks:(NSDictionary *)tasks {
    return [NSKeyedArchiver archiveRootObject:tasks toFile:_taskFilePath];
}

- (void)upload:(NSString *)identifier path:(NSString *)path {
    [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileUploaderUpload];
    NSURLSessionUploadTask *task = [_session uploadTaskWithRequest:_request fromFile:[NSURL fileURLWithPath:path isDirectory:NO]];
    NSArray *blob = @[identifier, path];
    [_tasks setObject:blob forKey:[NSNumber numberWithInteger:task.taskIdentifier]];
    [task resume];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        SFDebug(@"Could not complete upload due to %@", [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileUploaderNetworkError];
        return;
    }

    NSNumber *key = [NSNumber numberWithInteger:task.taskIdentifier];
    NSArray *blob = [_tasks objectForKey:key];
    [_tasks removeObjectForKey:key];

    // TODO(clchiou): How do we call methods of a subclass in Objective C?
    NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];

    SFDebug(@"POST %@ status %ld", task.response.URL, statusCode);
    if (blob && statusCode == 200) {
        NSString *identifier = blob[0];
        NSString *path = blob[1];
        SFDebug(@"Remove uploaded event file \"%@\"", path);
        [_manager useEventStore:identifier withBlock:^BOOL (SFEventFileStore *store) {
            return [store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *eventFilePaths) {
                NSError *error;
                if (![manager removeItemAtPath:path error:&error]) {
                    SFDebug(@"Could not remove uploaded event file \"%@\" due to %@", path, [error localizedDescription]);
                    [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileUploaderFileRemovalError];
                    return NO;
                }
                [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileUploaderUploadSuccess];
                return YES;
            }];
        }];
    }

    if (_completionHandler) {
        _completionHandler();
    }
}

@end


@implementation SFEventFileUploader (ApplicationState)

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    dispatch_async(_serialQueue, ^{
        [self saveTasks:_tasks];
    });
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    dispatch_async(_serialQueue, ^{
        [self saveTasks:_tasks];
    });
}

@end


@implementation SFEventFileUploader (Testing)

- (CompletionHandlerType)completionHandler {
    return _completionHandler;
}

- (void)setCompletionHandler:(CompletionHandlerType)completionHandler {
    self->_completionHandler = completionHandler;
}

- (NSDictionary *)tasks {
    return _tasks;
}

@end
