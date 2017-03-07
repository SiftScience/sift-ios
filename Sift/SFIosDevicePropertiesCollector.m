// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFEvent+Private.h"
#import "SFIosDeviceProperties.h"
#import "SFQueueConfig.h"
#import "Sift.h"

#import "SFIosDevicePropertiesCollector.h"

/**
 * Device properties are sent to their own queue, which is configured to
 * record only difference (we assume that device properties are rarely
 * changed).
 */
static const SFQueueConfig SFIosDevicePropertiesCollectorQueueConfig = {
    .appendEventOnlyWhenDifferent = YES,  // Only track difference.
    .acceptSameEventAfter = 3600  // 1 hour
};

static NSString * const SFIosDevicePropertiesCollectorQueueIdentifier = @"sift-devprops";

@interface SFIosDevicePropertiesCollector ()

/** Collect device properties through its own queue. */
- (void)collect;

@end

@implementation SFIosDevicePropertiesCollector

- (instancetype)init {
    self = [super init];
    if (self) {
        // Depending on when developer initializing the Sift object, we
        // could miss the "enter foreground" notification.  To be
        // foolproof, we add observer to both "enter foreground" and
        // "enter background" notifications.  Since device properties
        // queue is configured to record only differences, this would
        // not cause excess events.
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(collect) name:UIApplicationWillEnterForegroundNotification object:nil];
        [notificationCenter addObserver:self selector:@selector(collect) name:UIApplicationDidEnterBackgroundNotification object:nil];
    }
    return self;
}

- (void)collect {
    Sift *sift = Sift.sharedInstance;

    // Create queue lazily.
    if (![sift hasEventQueue:SFIosDevicePropertiesCollectorQueueIdentifier]) {
        if (![sift addEventQueue:SFIosDevicePropertiesCollectorQueueIdentifier config:SFIosDevicePropertiesCollectorQueueConfig]) {
            SF_DEBUG(@"Could not create \"%@\" queue", SFIosDevicePropertiesCollectorQueueIdentifier);
            return;
        }
    }

    SFEvent *event = [SFEvent new];
    event.iosDeviceProperties = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", event.iosDeviceProperties.entries);
    [sift appendEvent:event toQueue:SFIosDevicePropertiesCollectorQueueIdentifier];
}

@end
