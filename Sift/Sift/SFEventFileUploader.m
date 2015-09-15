// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFileUploader.h"
#import "SFEventFileUploader+Internal.h"

static NSString *SESSION_IDENTIFIER = @"com.sift.UploadSession";

static NSString *TRACKER_URL = @"https://b.siftscience.com/";

static NSString *TASK_FILE_NAME = @"tasks";

@implementation SFEventFileUploader {
    // TODO(clchiou): Properly manage life cycle of a session.
    NSURLSession *_session;

    SFEventFileManager *_manager;

    // TODO(clchiou): Persist this dict while app is suspended.
    NSString *_taskFilePath;
    NSMutableDictionary *_tasks;

    NSURLRequest *_tracker;

    // For testing.
    CompletionHandlerType _completionHandler;
}

- (id)initWithQueue:(NSOperationQueue *)queue manager:(SFEventFileManager *)manager rootDirPath:(NSString *)rootDirPath {
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:SESSION_IDENTIFIER];
    NSString *taskFilePath = [rootDirPath stringByAppendingPathComponent:TASK_FILE_NAME];
    return [self initWithQueue:queue manager:manager config:config trackerUrl:TRACKER_URL taskFilePath:taskFilePath];
}

- (id)initWithQueue:(NSOperationQueue *)queue
            manager:(SFEventFileManager *)manager
             config:(NSURLSessionConfiguration *)config
         trackerUrl:(NSString *)trackerUrl
       taskFilePath:(NSString *)taskFilePath {
    self = [super init];
    if (self) {
        _session = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:queue];

        _manager = manager;

        _taskFilePath = taskFilePath;
        _tasks = [self loadTasks];
        
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:trackerUrl]];
        request.HTTPMethod = @"POST";
        _tracker = request;

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

- (void)upload:(NSString *)path identifier:(NSString *)identifier {
    NSURLSessionUploadTask *task = [_session uploadTaskWithRequest:_tracker fromFile:[NSURL fileURLWithPath:path isDirectory:NO]];
    NSArray *blob = @[identifier, path];
    [_tasks setObject:blob forKey:[NSNumber numberWithInteger:task.taskIdentifier]];
    [task resume];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Could not complete upload due to %@", [error localizedDescription]);
        return;
    }

    NSNumber *key = [NSNumber numberWithInteger:task.taskIdentifier];
    NSArray *blob = [_tasks objectForKey:key];
    [_tasks removeObjectForKey:key];
    
    // TODO(clchiou): How do we call methods of a subclass in Objective C?
    NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];
    
    NSLog(@"POST %@ status %ld", task.response.URL, statusCode);
    if (blob && statusCode == 200) {
        NSString *identifier = blob[0];
        NSString *path = blob[1];
        NSLog(@"Remove uploaded event file \"%@\"", path);
        [_manager accessEventStore:identifier block:^BOOL (SFEventFileStore *store) {
            return [store accessEventFilesWithBlock:^BOOL (NSFileManager *manager, NSArray *eventFilePaths) {
                NSError *error;
                if (![manager removeItemAtPath:path error:&error]) {
                    NSLog(@"Could not remove uploaded event file \"%@\" due to %@", path, [error localizedDescription]);
                    return NO;
                }
                return YES;
            }];
        }];
    }
    
    if (_completionHandler) {
        _completionHandler();
    }
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