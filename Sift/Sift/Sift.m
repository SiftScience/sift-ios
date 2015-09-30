// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "pthread.h"

#import "SFConfig.h"
#import "SFEventFileManager.h"
#import "SFEventFileUploader.h"
#import "SFEventQueue.h"
#import "SFMetrics.h"
#import "SFMetricsReporter.h"
#import "SFUtil.h"

#import "Sift.h"
#import "Sift+Internal.h"

static NSString * const SFRootDirName = @"sift-v0_0_1";

static NSString * const SFDefaultEventQueueIdentifier = @"";

// TODO(clchiou): Add queues (and timers) for collecting stuff at background (e.g., iOS version).

// TODO(clchiou): Experiment a sensible config for the default event queue.
static const SFConfig SFDefaultEventQueueConfig = {
    .trackEventDifferenceOnly = NO,
    .rotateCurrentEventFileInterval = 5,
    .rotateCurrentEventFileIfOlderThan = 15,
    .rotateCurrentEventFileIfLargerThan = 512,
    .uploadEventFilesInterval = 60,
};

static Sift *SFSharedInstance;

@implementation Sift {
    NSString *_beaconKey;

    NSOperationQueue *_operationQueue;

    NSMutableDictionary *_eventQueues;
    pthread_rwlock_t _lock;  // Using a RW lock is easier than dispatch_barrier_async at the moment...

    SFEventFileManager *_manager;
    SFEventFileUploader *_uploader;

    SFMetricsReporter *_reporter;
}

+ (void)configureSharedInstance:(NSString *)beaconKey {
    [self configureSharedInstance:beaconKey serverUrl:nil];
}


+ (void)configureSharedInstance:(NSString *)beaconKey serverUrl:(NSString *)serverUrl {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SFSharedInstance = [[Sift alloc] initWithBeaconKey:beaconKey serverUrl:serverUrl rootDirPath:[SFCacheDirPath() stringByAppendingPathComponent:SFRootDirName]];
    });
}

+ (Sift *)sharedInstance {
    if (!SFSharedInstance) {
        SFDebug(@"sharedInstance was not initialized");
    }
    return SFSharedInstance;
}

- (instancetype)initWithBeaconKey:(NSString *)beaconKey serverUrl:(NSString *)serverUrl rootDirPath:(NSString *)rootDirPath {
    self = [super init];
    if (self) {
        _beaconKey = beaconKey;

        _operationQueue = [NSOperationQueue new];
        _eventQueues = [NSMutableDictionary new];
        pthread_rwlock_init(&_lock, NULL);

        _manager = [[SFEventFileManager alloc] initWithRootDir:rootDirPath];
        if (!_manager) {
            SFDebug(@"Could not initialize SFEventFileManager");
            self = nil;
            return nil;
        }

        _uploader = [[SFEventFileUploader alloc] initWithQueue:_operationQueue manager:_manager rootDirPath:rootDirPath serverUrl:serverUrl];
        if (!_uploader) {
            SFDebug(@"Could not initialize SFEventFileUploader");
            self = nil;
            return nil;
        }

        _reporter = [[SFMetricsReporter alloc] initWithMetrics:[SFMetrics sharedInstance] queue:_operationQueue];
        if (!_reporter) {
            SFDebug(@"Could not initialize SFMetricsReporter");
            self = nil;
            return nil;
        }
        _reporter.manager = _manager;

        // Create the default event queue.
        [self addEventQueue:SFDefaultEventQueueIdentifier config:SFDefaultEventQueueConfig];
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
            SFDebug(@"Could not overwrite event queue for identifier \"%@\"", identifier);
            return NO;
        }
        SFEventQueue *queue = [[SFEventQueue alloc] initWithIdentifier:identifier config:config queue:_operationQueue manager:_manager uploader:_uploader];
        if (!queue) {
            SFDebug(@"Could not create SFEventQueue for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues setObject:queue forKey:identifier];
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)removeEventQueue:(NSString *)identifier purge:(BOOL)purge {
    pthread_rwlock_wrlock(&_lock);
    @try {
        if (![_eventQueues objectForKey:identifier]) {
            SFDebug(@"Could not find event queue to be removed for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues removeObjectForKey:identifier];
        return [_manager removeEventStore:identifier purge:purge];
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (void)event:(NSDictionary *)event {
    [self event:event usingEventQueue:SFDefaultEventQueueIdentifier];
}

- (void)event:(NSDictionary *)event usingEventQueue:(NSString *)identifier {
    pthread_rwlock_rdlock(&_lock);
    @try {
        SFEventQueue *queue = [_eventQueues objectForKey:identifier];
        if (!queue) {
            SFDebug(@"Could not find event queue for identifier \"%@\" and will drop event", identifier);
            return;
        }
        [queue append:event withBeaconKey:_beaconKey];
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
