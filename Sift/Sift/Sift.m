// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "pthread.h"

#import "SFConfig.h"
#import "SFEventFileManager.h"
#import "SFEventFileUploader.h"
#import "SFEventQueue.h"
#import "SFUtil.h"

#import "Sift.h"

static NSString *ROOT_DIR_NAME = @"sift-v0_0_1";

static NSString *DEFAULT_EVENT_QUEUE_IDENTIFIER = @"";

static const SFConfig DEFAULT_EVENT_QUEUE_CONFIG = {
    .trackEventDifferenceOnly = NO,
    .rotateCurrentEventFileInterval = 5,
    .rotateCurrentEventFileIfOlderThan = 15,
    .rotateCurrentEventFileIfLargerThan = 512,
    .uploadEventFilesInterval = 60,
};

@implementation Sift {
    NSOperationQueue *_operationQueue;

    NSMutableDictionary *_eventQueues;
    pthread_rwlock_t _lock;  // Using a RW lock is easier than dispatch_barrier_async at the moment...

    SFEventFileManager *_manager;
    SFEventFileUploader *_uploader;
}

+ (Sift *)sharedInstance {
    static Sift *sharedInstance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedInstance = [[Sift alloc] initWithRootDirPath:[SFCacheDirPath() stringByAppendingPathComponent:ROOT_DIR_NAME]];
    });
    return sharedInstance;
}

- (id)initWithRootDirPath:(NSString *)rootDirPath {
    self = [super init];
    if (self) {
        _operationQueue = [NSOperationQueue new];
        _eventQueues = [NSMutableDictionary new];
        pthread_rwlock_init(&_lock, NULL);

        _manager = [[SFEventFileManager alloc] initWithRootDir:rootDirPath];
        if (!_manager) {
            NSLog(@"Could not initialize SFEventFileManager");
            self = nil;
            return nil;
        }

        _uploader = [[SFEventFileUploader alloc] initWithQueue:_operationQueue manager:_manager rootDirPath:rootDirPath];
        if (!_uploader) {
            NSLog(@"Could not initialize SFEventFileUploader");
            self = nil;
            return nil;
        }

        // Create the default event queue.
        [self addEventQueue:DEFAULT_EVENT_QUEUE_IDENTIFIER config:DEFAULT_EVENT_QUEUE_CONFIG];
    }
    return self;
}

- (void)dealloc {
    pthread_rwlock_destroy(&_lock);
    //[super dealloc];  // Provided by compiler!
}

- (BOOL)addEventQueue:(NSString *)identifier config:(SFConfig)config {
    pthread_rwlock_wrlock(&_lock);
    @try {
        if ([_eventQueues objectForKey:identifier]) {
            NSLog(@"Could not overwrite event queue for identifier \"%@\"", identifier);
            return NO;
        }        
        SFEventQueue *queue = [[SFEventQueue alloc] initWithIdentifier:identifier config:config queue:_operationQueue manager:_manager uploader:_uploader];
        if (!queue) {
            NSLog(@"Could not create SFEventQueue for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues setObject:queue forKey:identifier];
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)removeEventQueue:(NSString *)identifier {
    pthread_rwlock_wrlock(&_lock);
    @try {
        if (![_eventQueues objectForKey:identifier]) {
            NSLog(@"Could not find event queue to be removed for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues removeObjectForKey:identifier];
        return [_manager removeEventStore:identifier];
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (void)event:(NSDictionary *)event {
    [self event:event identifier:DEFAULT_EVENT_QUEUE_IDENTIFIER];
}

- (void)event:(NSDictionary *)event identifier:(NSString *)identifier {
    pthread_rwlock_rdlock(&_lock);
    @try {
        SFEventQueue *queue = [_eventQueues objectForKey:identifier];
        if (!queue) {
            NSLog(@"Could not find event queue for identifier \"%@\" and will drop event", identifier);
            return;
        }
        [queue append:event];
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

@end


@implementation Sift (Testing)

- (NSOperationQueue *)operationQueue {
    return _operationQueue;
}

- (void)setOperationQueue:(NSOperationQueue *)operationQueue {
    _operationQueue = operationQueue;
}

- (SFEventFileManager *)manager {
    return _manager;
}

- (void)setManager:(SFEventFileManager *)manager {
    _manager = manager;
}

- (SFEventFileUploader *)uploader {
    return _uploader;
}

- (void)setUploader:(SFEventFileUploader *)uploader {
    _uploader = uploader;
}

@end
