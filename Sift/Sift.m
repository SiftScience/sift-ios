// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "pthread.h"

#import "SFAppEventReporter.h"
#import "SFDebug.h"
#import "SFDevicePropertiesReporter.h"
#import "SFEvent.h"
#import "SFEvent+Utils.h"
#import "SFLocationReporter.h"
#import "SFMetrics.h"
#import "SFMetricsReporter.h"
#import "SFMotionReporter.h"
#import "SFQueue.h"
#import "SFQueueConfig.h"
#import "SFQueueDirs.h"
#import "SFUploader.h"
#import "SFUtils.h"

#import "Sift.h"
#import "Sift+Private.h"

static const NSTimeInterval SFUploadInterval = 60;  // 1 minute.
static const NSTimeInterval SFReportInterval = 60;  // 1 minute.
static const NSTimeInterval SFCleanupInterval = 600;  // 10 minutes.

static NSString * const SFServerUrlFormat = @"https://api3.siftscience.com/v3/accounts/%@/mobile_events";

static NSString * const SFRootDirName = @"sift-v0_0_1";

static NSString * const SFDefaultEventQueueIdentifier = @"sift-default";

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

    SFMetricsReporter *_metricsReporter;
    SFDevicePropertiesReporter *_devicePropertiesReporter;
    NSTimer *_reporterTimer;

    SFAppEventReporter *_appEventReporter;
    SFLocationReporter *_locationReporter;
    SFMotionReporter *_motionReporter;

    NSTimer *_cleanupTimer;
}

+ (instancetype)sharedInstance {
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
        _userId = nil;

        _operationQueue = operationQueue ?: [NSOperationQueue new];

        _eventQueues = [NSMutableDictionary new];
        pthread_rwlock_init(&_lock, NULL);

        _queueDirs = queueDirs ?: [[SFQueueDirs alloc] initWithRootDirPath:[rootDirPath stringByAppendingPathComponent:@"queues"]];
        if (!_queueDirs) {
            self = nil;
            return nil;
        }

        _uploader = uploader ?: [[SFUploader alloc] initWithRootDirPath:[rootDirPath stringByAppendingPathComponent:@"upload"] queueDirs:_queueDirs operationQueue:_operationQueue config:nil];
        if (!_uploader) {
            self = nil;
            return nil;
        }

        // Create the default event queue and the queue for device properties.
        if (![self addEventQueue:SFDefaultEventQueueIdentifier config:SFDefaultEventQueueConfig]) {
            self = nil;
            return nil;
        }
        if (![self addEventQueue:SFDevicePropertiesReporterQueueIdentifier config:SFDevicePropertiesReporterQueueConfig]) {
            self = nil;
            return nil;
        }

        _metricsReporter = [SFMetricsReporter new];
        if (!_metricsReporter) {
            self = nil;
            return nil;
        }
        _devicePropertiesReporter = [SFDevicePropertiesReporter new];
        if (!_devicePropertiesReporter) {
            self = nil;
            return nil;
        }

        _appEventReporter = [[SFAppEventReporter alloc] initWithQueue:_operationQueue];
        if (!_appEventReporter) {
            self = nil;
            return nil;
        }
        _locationReporter = [SFLocationReporter new];
        if (!_locationReporter) {
            self = nil;
            return nil;
        }
        _motionReporter = [SFMotionReporter new];
        if (!_motionReporter) {
            self = nil;
            return nil;
        }

        [_locationReporter start];
        [_motionReporter start];

        _uploaderTimer = nil;
        self.uploadPeriod = SFUploadInterval;

        _reporterTimer = nil;
        self.reportPeriod = SFReportInterval;

        _cleanupTimer = [NSTimer timerWithTimeInterval:SFCleanupInterval target:self selector:@selector(enqueueMethod:) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:_cleanupTimer forMode:NSDefaultRunLoopMode];

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)dealloc {
    if (_uploaderTimer) {
        [_uploaderTimer invalidate];
    }
    if (_reporterTimer) {
        [_reporterTimer invalidate];
    }
    if (_cleanupTimer) {
        [_cleanupTimer invalidate];
    }
    pthread_rwlock_destroy(&_lock);
    //[super dealloc];  // Provided by compiler!
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    SF_DEBUG(@"Enter foreground...");
    // If for any reason that the location reporter is stopped, let's start it again.
    if (!_locationReporter.started) {
        [_locationReporter start];
    }
    // Restart the motion reporter.
    [_motionReporter start];
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    SF_DEBUG(@"Enter background...");
    // Persist metrics data (simply create a report from them).
    @synchronized(self) {
        SF_DEBUG(@"Report metrics... (app enters background)");
        if (SFEventIsEmptyUserId(_userId)) {
            SF_DEBUG(@"Refuse to collect device fingerprint when no user ID is present");
            return;
        }
        [_metricsReporter report:_userId];
    }
    // Stop motion reporter (as it's very, very chatty).
    [_motionReporter stop];
}

- (void)removeData {
    SF_DEBUG(@"Remove data...");
    [_queueDirs removeData];
    [_uploader removeData];
}

- (void)setUploadPeriod:(NSTimeInterval)uploadPeriod {
    [self configureTimer:_uploaderTimer period:&_uploadPeriod newPeriod:uploadPeriod];
}

- (void)setReportPeriod:(NSTimeInterval)reportPeriod {
    [self configureTimer:_reporterTimer period:&_reportPeriod newPeriod:reportPeriod];
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
        SF_DEBUG(@"Cannot recognize timer %@", timer);
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
        SF_DEBUG(@"Cancel background %@", @[@"uploader", @"reporter"][timerSelection]);
        return;
    }

    SF_DEBUG(@"Start background %@ with period %.2f", @[@"uploader", @"reporter"][timerSelection], *period);
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
    } else if (timer == _cleanupTimer) {
        selector = @selector(cleanup);
    } else {
        SFFail();
        return;
    }
    if (selector) {
        [_operationQueue addOperation:[[NSInvocationOperation alloc] initWithTarget:self selector:selector object:nil]];
    }
}

- (BOOL)upload {
    return [self upload:NO];
}

- (BOOL)upload:(BOOL)force {
    if (!_serverUrlFormat || !_accountId || !_beaconKey) {
        SF_DEBUG(@"Cannot upload events due to lack of server URL format, account ID, and/or beacon key");
        return NO;
    }
    SF_DEBUG(@"Rotate queues...");
    pthread_rwlock_rdlock(&_lock);
    @try {
        for (NSString *identifier in _eventQueues) {
            [[_eventQueues objectForKey:identifier] maybeRotateFile];
        }
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
    SF_DEBUG(@"Upload events...");
    return [_uploader upload:_serverUrlFormat accountId:_accountId beaconKey:_beaconKey force:force];
}

- (void)report {
    @synchronized(self) {
        if (SFEventIsEmptyUserId(_userId)) {
            SF_DEBUG(@"Refuse to collect device fingerprint when no user ID is present");
            return;
        }
        SF_DEBUG(@"Report metrics...");
        [_metricsReporter report:_userId];
        SF_DEBUG(@"Report device properties...");
        [_devicePropertiesReporter report:_userId];
    }
}

- (void)cleanup {
    SF_DEBUG(@"Clean up...");
    [_queueDirs cleanup];
    [_uploader cleanup];
}

- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config {
    pthread_rwlock_wrlock(&_lock);
    @try {
        if ([_eventQueues objectForKey:identifier]) {
            SF_DEBUG(@"Could not overwrite event queue for identifier \"%@\"", identifier);
            return NO;
        }
        SFQueue *queue = [[SFQueue alloc] initWithIdentifier:identifier config:config operationQueue:_operationQueue queueDirs:_queueDirs];
        if (!queue) {
            SF_DEBUG(@"Could not create SFEventQueue for identifier \"%@\"", identifier);
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
            SF_DEBUG(@"Could not find event queue to be removed for identifier \"%@\"", identifier);
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
            SF_DEBUG(@"Could not find event queue for identifier \"%@\" and will drop event", identifier);
            return NO;
        }
        if (SFEventIsEmptyUserId(event.userId)) {
            if (SFEventIsEmptyUserId(_userId)) {
                SF_DEBUG(@"event.userId is not optional");
                return NO;
            }
            SF_DEBUG(@"The event's userId is empty; use Sift object's userId: \"%@\"", _userId);
            event.userId = _userId;
        }
        [queue append:[event makeEvent]];
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)flush {
    SF_DEBUG(@"Flush out events...");
    pthread_rwlock_rdlock(&_lock);
    @try {
        for (NSString *identifier in _eventQueues) {
            SFQueue *queue = [_eventQueues objectForKey:identifier];
            [queue rotateFile];
        }
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

@end
