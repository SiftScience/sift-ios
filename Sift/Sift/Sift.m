// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "pthread.h"

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Utils.h"
#import "SFMetrics.h"
#import "SFMetricsReporter.h"
#import "SFQueue.h"
#import "SFQueueConfig.h"
#import "SFQueueDirs.h"
#import "SFUploader.h"
#import "SFUtils.h"

#import "Sift.h"
#import "Sift+Private.h"

// TODO(clchiou): Add queues (and timers) for collecting stuff at background (e.g., iOS version).

static const NSTimeInterval SFUploadInterval = 60;  // 1 minute.
static const NSTimeInterval SFReportMetricsInterval = 60.0;  // 1 minute.

static NSString * const SFServerUrlFormat = @"https://api3.siftscience.com/v3/accounts/%@/mobile_events";

static NSString * const SFRootDirName = @"sift-v0_0_1";

static NSString * const SFDefaultEventQueueIdentifier = @"";

// TODO(clchiou): Experiment a sensible config for the default event queue.
static const SFQueueConfig SFDefaultEventQueueConfig = {
    .appendEventOnlyWhenDifferent = NO,
    .rotateWhenLargerThan = 4096,  // 4 KB
    .rotateWhenOlderThan = 60,  // 1 minute
};

@implementation Sift {
    NSString *_serverUrlFormat;
    NSString *_accountId;
    NSString *_beaconKey;

    NSOperationQueue *_operationQueue;

    NSMutableDictionary *_eventQueues;
    pthread_rwlock_t _lock;  // Using a RW lock is easier than dispatch_barrier_async at the moment...

    SFQueueDirs *_queueDirs;

    SFUploader *_uploader;
    NSTimer *_uploaderTimer;

    SFMetricsReporter *_reporter;
    NSTimer *_reporterTimer;
}

+ (instancetype)sharedSift {
    static Sift *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[Sift alloc] initWithRootDirPath:[SFCacheDirPath() stringByAppendingPathComponent:SFRootDirName] operationQueue:nil queueDir:nil uploader:nil];
    });
    return instance;
}

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath operationQueue:(NSOperationQueue *)operationQueue queueDir:(SFQueueDirs *)queueDirs uploader:(SFUploader *)uploader {
    self = [super init];
    if (self) {
        _serverUrlFormat = SFServerUrlFormat;
        _accountId = nil;
        _beaconKey = nil;

        _operationQueue = operationQueue ?: [NSOperationQueue new];

        _eventQueues = [NSMutableDictionary new];
        pthread_rwlock_init(&_lock, NULL);

        _queueDirs = queueDirs ?: [[SFQueueDirs alloc] initWithRootDirPath:rootDirPath];
        if (!_queueDirs) {
            self = nil;
            return nil;
        }

        _uploader = uploader ?: [[SFUploader alloc] initWithRootDirPath:rootDirPath queueDirs:_queueDirs operationQueue:_operationQueue config:nil];
        if (!_uploader) {
            self = nil;
            return nil;
        }

        // Create the default event queue.
        if (![self addEventQueue:SFDefaultEventQueueIdentifier config:SFDefaultEventQueueConfig]) {
            self = nil;
            return nil;
        }

        _reporter = [SFMetricsReporter new];
        if (!_reporter) {
            self = nil;
            return nil;
        }

        _uploaderTimer = nil;
        self.uploadPeriod = SFUploadInterval;

        _reporterTimer = nil;
        self.reportMetricsPeriod = SFReportMetricsInterval;
    }
    return self;
}

- (void)dealloc {
    pthread_rwlock_destroy(&_lock);
    //[super dealloc];  // Provided by compiler!
}

- (void)setUploadPeriod:(NSTimeInterval)uploadPeriod {
    [self configureTimer:_uploaderTimer period:&_uploadPeriod newPeriod:uploadPeriod];
}

- (void)setReportMetricsPeriod:(NSTimeInterval)reportMetricsPeriod {
    [self configureTimer:_reporterTimer period:&_reportMetricsPeriod newPeriod:reportMetricsPeriod];
}

- (void)configureTimer:(NSTimer *)timer period:(NSTimeInterval *)period newPeriod:(NSTimeInterval)newPeriod {
    enum {
        UPLOADER,
        REPORTER,
    } timerSelection;

#define SET(value) \
    do { \
        if (timerSelection == UPLOADER) { \
            _uploaderTimer = (value); \
        } else if (timerSelection == REPORTER) { \
            _reporterTimer = (value); \
        } else { \
            SFFail(); \
        } \
    } while (0);

    if (timer == _uploaderTimer) {
        timerSelection = UPLOADER;
    } else if (timer == _reporterTimer) {
        timerSelection = REPORTER;
    } else {
        SFDebug(@"Cannot recognize timer %@", timer);
        return;
    }

    if (*period == newPeriod) {
        return;
    }

    if (!timer) {
        [timer invalidate];
        SET(nil);
        if (timerSelection == UPLOADER) {
            _uploaderTimer = nil;
        } else if (timerSelection == REPORTER) {
            _reporterTimer = nil;
        } else {
            SFFail();
        }
    }

    *period = newPeriod;
    if (*period <= 0) {
        SFDebug(@"Cancel background %@", @[@"uploader", @"reporter"][timerSelection]);
        return;
    }

    SFDebug(@"Start background %@ with period %.2f", @[@"uploader", @"reporter"][timerSelection], *period);
    timer = [NSTimer timerWithTimeInterval:*period target:self selector:@selector(enqueueMethod:) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:timer forMode:NSDefaultRunLoopMode];
    SET(timer);

#undef SET
}

- (void)enqueueMethod:(NSTimer *)timer {
    SEL selector = nil;
    if (timer == _uploaderTimer) {
        selector = @selector(upload);
    } else if (timer == _reporterTimer) {
        selector = @selector(report);
    } else {
        SFDebug(@"Cannot recognize this timer %@", timer);
    }
    if (selector) {
        [_operationQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:selector object:nil]];
    }
}

- (BOOL)upload {
    if (!_serverUrlFormat || !_accountId || !_beaconKey) {
        SFDebug(@"Cannot upload events due to lack of server URL format, account ID, and/or beacon key");
        return NO;
    }
    @synchronized(self) {
        SFDebug(@"Upload events...");
        return [_uploader upload:_serverUrlFormat accountId:_accountId beaconKey:_beaconKey];
    }
}

- (void)report {
    @synchronized(self) {
        SFDebug(@"Report metrics...");
        [_reporter report];
    }
}

- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config {
    pthread_rwlock_wrlock(&_lock);
    @try {
        if ([_eventQueues objectForKey:identifier]) {
            SFDebug(@"Could not overwrite event queue for identifier \"%@\"", identifier);
            return NO;
        }
        SFQueue *queue = [[SFQueue alloc] initWithIdentifier:identifier config:config operationQueue:_operationQueue queueDirs:_queueDirs];
        if (!queue) {
            SFDebug(@"Could not create SFEventQueue for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues setObject:queue forKey:identifier];
        [_queueDirs addDir:identifier];
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
        return [_queueDirs removeDir:identifier purge:purge];
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)appendEvent:(SFEvent *)event {
    return [self appendEvent:event toQueue:SFDefaultEventQueueIdentifier];
}

- (BOOL)appendEvent:(SFEvent *)event toQueue:(NSString *)identifier {
    pthread_rwlock_rdlock(&_lock);
    @try {
        SFQueue *queue = [_eventQueues objectForKey:identifier];
        if (!queue) {
            SFDebug(@"Could not find event queue for identifier \"%@\" and will drop event", identifier);
            return NO;
        }
        [queue append:[event makeEvent]];
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

@end
