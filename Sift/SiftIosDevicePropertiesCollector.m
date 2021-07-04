// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SiftDebug.h"
#import "SiftEvent.h"
#import "SiftEvent+Private.h"
#import "SiftIosDeviceProperties.h"
#import "SiftQueueConfig.h"
#import "Sift.h"

#import "SiftIosDevicePropertiesCollector.h"

/**
 * Device properties are sent to their own queue, which is configured to
 * record only difference (we assume that device properties are rarely
 * changed).
 */
static const SiftQueueConfig SFIosDevicePropertiesCollectorQueueConfig = {
    .uploadWhenMoreThan = 0,
    .acceptSameEventAfter = 3600  // 1 hour
};

static NSString * const SFIosDevicePropertiesCollectorQueueIdentifier = @"sift-devprops";

@interface SiftIosDevicePropertiesCollector ()

/** Collect device properties through its own queue. */
- (void)collect;

@end

@implementation SiftIosDevicePropertiesCollector

- (instancetype)init {
    self = [super init];
    if (self) {
        // Observe didBecomeActive to capture the initial application start-up
        NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
        [notificationCenter addObserver:self selector:@selector(collect) name:UIApplicationDidBecomeActiveNotification object:nil];
        
        // Depending on when the developer initializes the Sift object, we
        // could miss the "enter foreground" notification.  To be
        // foolproof, we add observer to both "enter foreground" and
        // "enter background" notifications.  Since device properties
        // queue is configured to record only differences, this would
        // not cause excess events.
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

    SiftEvent *event = [SiftEvent new];
    event.iosDeviceProperties = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", event.iosDeviceProperties);
    [sift appendEvent:event toQueue:SFIosDevicePropertiesCollectorQueueIdentifier];
}

@end
