// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFEventFileUploader ()

- (id)initWithQueue:(NSOperationQueue *)queue
            manager:(SFEventFileManager *)manager
             config:(NSURLSessionConfiguration *)config
         trackerUrl:(NSString *)trackerUrl
       taskFilePath:(NSString *)taskFilePath;

- (NSMutableDictionary *)loadTasks;

- (BOOL)saveTasks:(NSDictionary *)tasks;

@end


@interface SFEventFileUploader (ApplicationState)

- (void)applicationDidEnterBackground:(NSNotification *)notification;

- (void)applicationWillTerminate:(NSNotification *)notification;

@end


@interface SFEventFileUploader (Testing)

typedef void (^CompletionHandlerType)(void);

@property (nonatomic) CompletionHandlerType completionHandler;

@property (readonly, nonatomic) NSDictionary *tasks;

@end