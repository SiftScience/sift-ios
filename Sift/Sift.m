// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"
#import "SFIosAppStateCollector.h"
#import "SFIosDevicePropertiesCollector.h"
#import "SFQueue.h"
#import "SFQueueConfig.h"
#import "SFUploader.h"
#import "SFUtils.h"

#import "Sift.h"
#import "Sift+Private.h"

static NSString * const SFServerUrlFormat = @"https://api3.siftscience.com/v3/accounts/%@/mobile_events";

static NSString * const SFRootDirName = @"sift-v0_0_1";

static NSString * const SFDefaultEventQueueIdentifier = @"sift-default";

// TODO(clchiou): Experiment a sensible config for the default event queue.
static const SFQueueConfig SFDefaultEventQueueConfig = {
    .uploadWhenMoreThan = 32,  // Unit: number of events.
    .uploadWhenOlderThan = 60,  // 1 minute.
};

@implementation Sift {
    NSString *_rootDirPath;

    NSString *_accountId;
    NSString *_beaconKey;
    NSString *_userId;

    NSMutableDictionary *_eventQueues;
    SFUploader *_uploader;

    // Extra collection mechanisms.
    SFIosAppStateCollector *_iosAppStateCollector;
    SFIosDevicePropertiesCollector *_iosDevicePropertiesCollector;
}

+ (instancetype)sharedInstance {
    static Sift *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [[Sift alloc] initWithRootDirPath:[SFCacheDirPath() stringByAppendingPathComponent:SFRootDirName]];
    });
    return instance;
}

- (instancetype)initWithRootDirPath:(NSString *)rootDirPath {
    self = [super init];
    if (self) {
        _sdkVersion = @"v0.9.10";

        _rootDirPath = rootDirPath;

        _serverUrlFormat = SFServerUrlFormat;

        [self unarchiveKeys];

        _eventQueues = [NSMutableDictionary new];

        _uploader = [[SFUploader alloc] initWithArchivePath:self.archivePathForUploader sift:self];
        if (!_uploader) {
            self = nil;
            return nil;
        }

        // Create the default event queue.
        if (![self addEventQueue:SFDefaultEventQueueIdentifier config:SFDefaultEventQueueConfig]) {
            self = nil;
            return nil;
        }
        _defaultQueueIdentifier = SFDefaultEventQueueIdentifier;

        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(applicationDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];

        // Create autonomous data collection.
        _iosAppStateCollector = [[SFIosAppStateCollector alloc] initWithArchivePath:self.archivePathForIosAppStateCollector];
        if (!_iosAppStateCollector) {
            SF_DEBUG(@"Could not create _iosAppStateCollector");
            self = nil;
            return nil;
        }
        _iosDevicePropertiesCollector = [SFIosDevicePropertiesCollector new];
        if (!_iosDevicePropertiesCollector) {
            SF_DEBUG(@"Could not create _iosDevicePropertiesCollector");
            self = nil;
            return nil;
        }
    }
    return self;
}

- (void)applicationDidEnterBackground:(NSNotification *)notification {
    SF_DEBUG(@"Enter background");
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
        [self archive];
    });
}

- (BOOL)hasEventQueue:(NSString *)identifier {
    @synchronized (_eventQueues) {
        return [_eventQueues objectForKey:identifier] ? YES : NO;
    }
}

- (BOOL)addEventQueue:(NSString *)identifier config:(SFQueueConfig)config {
    @synchronized(_eventQueues) {
        if ([_eventQueues objectForKey:identifier]) {
            SF_DEBUG(@"Could not overwrite event queue for identifier \"%@\"", identifier);
            return NO;
        }
        NSString *archivePath = [self archivePathForQueue:identifier];
        SFQueue *queue = [[SFQueue alloc] initWithIdentifier:identifier config:config archivePath:archivePath sift:self];
        if (!queue) {
            SF_DEBUG(@"Could not create SFEventQueue for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues setObject:queue forKey:identifier];
        return YES;
    }
}

- (BOOL)removeEventQueue:(NSString *)identifier {
    @synchronized(_eventQueues) {
        if (![_eventQueues objectForKey:identifier]) {
            SF_DEBUG(@"Could not find event queue to be removed for identifier \"%@\"", identifier);
            return NO;
        }
        [_eventQueues removeObjectForKey:identifier];
        return YES;
    }
}

- (BOOL)appendEvent:(SFEvent *)event {
    return [self appendEvent:event toQueue:_defaultQueueIdentifier];
}

- (BOOL)appendEvent:(SFEvent *)event toQueue:(NSString *)identifier {
    @synchronized(_eventQueues) {
        SFQueue *queue = [_eventQueues objectForKey:identifier];
        if (!queue) {
            SF_DEBUG(@"Could not find event queue for identifier \"%@\" and will drop event", identifier);
            return NO;
        }
        // Record user ID when receiving the event, not when uploading the event.
        if (!event.userId.length && _userId.length) {
            SF_DEBUG(@"The event's userId is empty; use Sift object's userId: \"%@\"", _userId);
            event.userId = _userId;
        }
        if (![event sanityCheck]) {
            SF_DEBUG(@"Drop event due to incorrect contents: %@", event);
            return NO;
        }
        SF_IMPORTANT(@"Append an event of type \"%@\" to queue \"%@\"", event.type, identifier);
        [queue append:event];
        return YES;
    }
}

- (BOOL)upload {
    return [self upload:NO];
}

- (BOOL)upload:(BOOL)force {
    if (!_accountId || !_beaconKey || !_serverUrlFormat) {
        SF_DEBUG(@"Lack _accountId, _beaconKey, and/or _serverUrlFormat");
        return NO;
    }

    NSMutableArray *events = [NSMutableArray new];
    @synchronized(_eventQueues) {
        for (NSString *identifier in _eventQueues) {
            SFQueue *queue = [_eventQueues objectForKey:identifier];
            if (force || queue.readyForUpload) {
                [events addObjectsFromArray:[queue transfer]];
            }
        }
    }
    if (!events.count) {
        SF_DEBUG(@"No events to upload");
        return NO;
    }

    [_uploader upload:events];
    return YES;
}

#pragma mark - Account keys

- (NSString *)accountId {
    return _accountId;
}

- (void)setAccountId:(NSString *)accountId {
    _accountId = accountId;
    [self archiveKeys];
}

- (NSString *)beaconKey {
    return _beaconKey;
}

- (void)setBeaconKey:(NSString *)beaconKey {
    _beaconKey = beaconKey;
    [self archiveKeys];
}

- (NSString *)userId {
    return _userId;
}

- (void)setUserId:(NSString *)userId {
    _userId = userId;
    [self archiveKeys];
}


- (BOOL)allowUsingMotionSensors {
    return [_iosAppStateCollector allowUsingMotionSensors];
}

- (void)setAllowUsingMotionSensors:(BOOL)allowUsingMotionSensors {
    [_iosAppStateCollector setAllowUsingMotionSensors:allowUsingMotionSensors];
}


- (void)updateDeviceMotion:(CMDeviceMotion *)data {
    [_iosAppStateCollector updateDeviceMotion:data];
}

- (void)updateAccelerometerData:(CMAccelerometerData *)data {
    [_iosAppStateCollector updateAccelerometerData:data];
}

- (void)updateGyroData:(CMGyroData *)data {
    [_iosAppStateCollector updateGyroData:data];
}

- (void)updateMagnetometerData:(CMMagnetometerData *)data {
    [_iosAppStateCollector updateMagnetometerData:data];
}


- (BOOL)disallowCollectingLocationData {
    return [_iosAppStateCollector disallowCollectingLocationData];
}

- (void)setDisallowCollectingLocationData:(BOOL)disallowCollectingLocationData {
    [_iosAppStateCollector setDisallowCollectingLocationData:disallowCollectingLocationData];
}

#pragma mark - NSKeyedArchiver/NSKeyedUnarchiver

static NSString * const SF_SIFT = @"sift";
static NSString * const SF_SIFT_ACCOUNT_ID = @"accountId";
static NSString * const SF_SIFT_BEACON_KEY = @"beaconKey";
static NSString * const SF_SIFT_USER_ID = @"userId";

static NSString * const SF_QUEUE_DIR = @"queues";
static NSString * const SF_IOS_APP_STATE_COLLECTOR = @"ios_app_state_collector";
static NSString * const SF_UPLOADER = @"uploader";

- (NSString *)archivePathForKeys {
    return [_rootDirPath stringByAppendingPathComponent:SF_SIFT];
}

- (NSString *)archivePathForQueue:(NSString *)identifier {
    return [[_rootDirPath stringByAppendingPathComponent:SF_QUEUE_DIR] stringByAppendingPathComponent:identifier];
}

- (NSString *)archivePathForIosAppStateCollector {
    return [_rootDirPath stringByAppendingPathComponent:SF_IOS_APP_STATE_COLLECTOR];
}

- (NSString *)archivePathForUploader {
    return [_rootDirPath stringByAppendingPathComponent:SF_UPLOADER];
}

- (void)archive {
    [self archiveKeys];
    @synchronized(_eventQueues) {
        for (NSString *identifier in _eventQueues) {
            [[_eventQueues objectForKey:identifier] archive];
        }
    }
    [_uploader archive];
    [_iosAppStateCollector archive];
}

- (void)archiveKeys {
    NSMutableDictionary *archive = [NSMutableDictionary new];
    if (_accountId) {
        [archive setObject:_accountId forKey:SF_SIFT_ACCOUNT_ID];
    }
    if (_beaconKey) {
        [archive setObject:_beaconKey forKey:SF_SIFT_BEACON_KEY];
    }
    if (_userId) {
        [archive setObject:_userId forKey:SF_SIFT_USER_ID];
    }
    [NSKeyedArchiver archiveRootObject:archive toFile:[self archivePathForKeys]];
}

- (void)unarchiveKeys {
    NSDictionary *archive = [NSKeyedUnarchiver unarchiveObjectWithFile:[self archivePathForKeys]];
    if (archive) {
        _accountId = [archive objectForKey:SF_SIFT_ACCOUNT_ID];
        _beaconKey = [archive objectForKey:SF_SIFT_BEACON_KEY];
        _userId = [archive objectForKey:SF_SIFT_USER_ID];
    } else {
        _accountId = nil;
        _beaconKey = nil;
        _userId = nil;
    }
    SF_DEBUG(@"Unarchive: accountId=%@ beaconKey=%@ userId=%@", _accountId, _beaconKey, _userId);
}

@end
