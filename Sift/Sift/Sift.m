// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventsFileManager.h"

#import "Sift.h"
#import "SiftInternal.h"

NSString *TRACKER = @"https://b.siftscience.com/";

NSString *IDENTIFIER = @"com.sift.BeaconBackgroundSession";

// Remind us to check currentEventsFile every 10 seconds (should we make this configurable?).
NSTimeInterval REMIND_CHECK_CURRENT_EVENTS_FILE_INTERVAL = 10.0;

NSTimeInterval REMIND_UPLOAD_EVENTS_INTERVAL = 30.0;

@implementation Sift {
    NSOperationQueue *_queue;

    SFEventsFileManager *_manager;

    // TODO(clchiou): Properly manage life cycle of a session.
    NSURLSession *_session;
    // TODO(clchiou): Should we persist this dict while app is suspended?
    NSMutableDictionary *_uploadTaskFilePaths;

    // Protected by @synchronized(self).
    NSURLRequest *_trackerRequest;
}

+ (Sift *)sharedInstance {
    static Sift *sharedInstance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[Sift alloc] initWithIdentifier:IDENTIFIER manager:[SFEventsFileManager sharedInstance]];
    });
    return sharedInstance;
}

- (id)initWithIdentifier:(NSString *)identifier manager:(SFEventsFileManager *)manager {
    self = [super init];
    if (self) {
        _queue = [NSOperationQueue new];

        _manager = manager;

        _session = [NSURLSession sessionWithConfiguration:defaultConfigurationWithIdentifier(identifier) delegate:self delegateQueue:_queue];
        _uploadTaskFilePaths = [NSMutableDictionary new];
        self.tracker = TRACKER;
        
        // Create a timer on the main run loop that remind us to check the current events file.
        NSTimer *timer;
        timer = [NSTimer timerWithTimeInterval:REMIND_CHECK_CURRENT_EVENTS_FILE_INTERVAL target:self selector:@selector(remindCheckCurrentEventsFile:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
        
        timer = [NSTimer timerWithTimeInterval:REMIND_UPLOAD_EVENTS_INTERVAL target:self selector:@selector(remindUploadEventsFiles:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    }
    return self;
}

- (NSString *)tracker {
    @synchronized(self) {
        return _trackerRequest.URL.absoluteString;
    }
}

- (void)setTracker:(NSString *)tracker {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:tracker]];
    request.HTTPMethod = @"POST";
    @synchronized(self) {
        _trackerRequest = request;
    }
}

- (SFEventsFileManager *)manager {
    return _manager;
}

NSURLSessionConfiguration *defaultConfigurationWithIdentifier(NSString *identifier) {
    return [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:identifier];
}

- (void)event:(NSDictionary *)data {
    [_queue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(writeToCurrentEventsFile:) object:createEvent(data)]];
}

NSData *createEvent(NSDictionary *data) {
    // TODO(clchiou): Compare JSON and archivedDataWithRootObject.
    return [NSKeyedArchiver archivedDataWithRootObject:data];
}

NSDictionary *readEvent(NSData *data, NSUInteger *location) {
    uint32_t length;
    NSRange range = {*location, sizeof(length)};
    [data getBytes:&length range:range];
    length = CFSwapInt32LittleToHost(length);
    
    range.location += range.length;
    range.length = length;
    NSDictionary *event = [NSKeyedUnarchiver unarchiveObjectWithData:[data subdataWithRange:range]];

    *location = range.location + range.length;
    return event;
}

- (void)writeToCurrentEventsFile:(NSData *)event {
    uint32_t length = CFSwapInt32HostToLittle((uint32_t)event.length);
    [_manager writeCurrentEventsFile:^(NSFileHandle *currentEventsFile) {
        // TODO(clchiou): Handle disk write failure.
        [currentEventsFile writeData:[NSData dataWithBytes:&length length:sizeof(length)]];
        [currentEventsFile writeData:event];

        if (self.eventPersistedCallback) {
            self.eventPersistedCallback(currentEventsFile, event);
        }
    }];
}

- (void)remindCheckCurrentEventsFile:(NSTimer *)timer {
    [_queue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(checkCurrentEventsFile) object:nil]];
}

- (void)checkCurrentEventsFile {
    [_manager maybeRotateCurrentEventsFile:NO];
}

- (void)remindUploadEventsFiles:(NSTimer *)timer {
    [_queue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:@selector(uploadEventsFiles) object:nil]];
}

- (void)uploadEventsFiles {
    @synchronized(self) {
        [_manager processEventsFiles:^(NSFileManager *manager, NSArray *paths) {
            for (NSString *path in paths) {
                NSURLSessionUploadTask *task = [_session uploadTaskWithRequest:_trackerRequest fromFile:[NSURL fileURLWithPath:path isDirectory:NO]];
                [_uploadTaskFilePaths setObject:path forKey:[NSNumber numberWithInteger:task.taskIdentifier]];
                [task resume];
            }
        }];
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        NSLog(@"Session task failed due to %@", [error localizedDescription]);
    }

    NSNumber *key = [NSNumber numberWithInteger:task.taskIdentifier];
    NSString *path = [_uploadTaskFilePaths objectForKey:key];
    [_uploadTaskFilePaths removeObjectForKey:key];

    // TODO(clchiou): How do we call methods of a subclass in Objective C?
    NSInteger statusCode = [(NSHTTPURLResponse *)task.response statusCode];

    NSLog(@"POST \"%@\" to %@ with status %ld", path, task.response.URL, statusCode);
    if (statusCode == 200) {
        [_manager processEventsFiles:^(NSFileManager *manager, NSArray *paths) {
            if ([paths containsObject:path]) {
                NSLog(@"Remove events file \"%@\"", path);
                NSError *error;
                if (![manager removeItemAtPath:path error:&error]) {
                    NSLog(@"Could not remove \"%@\" due to %@", path, [error localizedDescription]);
                }
            } else {
                NSLog(@"Could not remove \"%@\" becaues it has already been removed", path);
            }
        }];
    }

    if (self.uploadTaskCompletionCallback) {
        self.uploadTaskCompletionCallback(session, task, error);
    }
}

@end