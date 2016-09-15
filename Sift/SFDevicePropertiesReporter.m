// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"
#import "SFIosDeviceProperties.h"
#import "SFQueueConfig.h"
#import "Sift.h"

#import "SFDevicePropertiesReporter.h"

/**
 * Device properties are sent to their own queue, which is configured to
 * record only difference (we assume that device properties are rarely
 * changed).
 */
static const SFQueueConfig SFDevicePropertiesReporterQueueConfig = {
    .appendEventOnlyWhenDifferent = YES,  // Only track difference.
    .acceptSameEventAfter = 600,  // 10 minutes
    .uploadWhenMoreThan = 8,  // More than 8 events
    .uploadWhenOlderThan = 60,  // 1 minute
};

static NSString * const SFDevicePropertiesReporterQueueIdentifier = @"sift-devprops";

static const int64_t SF_START = 0;  // Start immediately
static const int64_t SF_INTERVAL = 60 * NSEC_PER_SEC;  // Repeate every 1 minute
static const int64_t SF_LEEWAY = 5 * NSEC_PER_SEC;

@interface SFDevicePropertiesReporter ()

/** Report device properties through its own queue. */
- (void)report;

@end

@implementation SFDevicePropertiesReporter {
    dispatch_source_t _source;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        Sift *sift = [Sift sharedInstance];
        if (![sift addEventQueue:SFDevicePropertiesReporterQueueIdentifier config:SFDevicePropertiesReporterQueueConfig]) {
            SF_DEBUG(@"Could not create \"%@\" queue", SFDevicePropertiesReporterQueueIdentifier);
            self = nil;
            return nil;
        }

        _source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0));
        dispatch_source_set_timer(_source, dispatch_time(DISPATCH_TIME_NOW, SF_START), SF_INTERVAL, SF_LEEWAY);
        SFDevicePropertiesReporter * __weak weakSelf = self;
        dispatch_source_set_event_handler(_source, ^{[weakSelf report];});
        dispatch_resume(_source);
    }
    return self;
}

- (void)report {
    SFEvent *event = [SFEvent new];
    event.iosDeviceProperties = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", event.iosDeviceProperties.entries);
    [Sift.sharedInstance appendEvent:event toQueue:SFDevicePropertiesReporterQueueIdentifier];
}

@end
