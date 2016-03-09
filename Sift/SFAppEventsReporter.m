// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "Sift.h"

#import "SFAppEventsReporter.h"

// List of notification prefixes that a fraud analyst might care.
//
// TODO(clchiou): Add more notifications here (and before you add them,
// make sure a fraud analyst would be able to understand their meaning).
static NSString * const SFNotificationNames[] = {
    @"UIApplicationDidEnterBackgroundNotification",
    @"UIApplicationDidBecomeActiveNotification",
    nil,
};

@implementation SFAppEventsReporter {
    NSOperationQueue *_queue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [NSOperationQueue new];
        for (int i = 0; SFNotificationNames[i]; i++) {
            [[NSNotificationCenter defaultCenter] addObserverForName:SFNotificationNames[i] object:nil queue:_queue usingBlock:^(NSNotification *note) {
                SF_DEBUG(@"Notified with \"%@\"", note.name);
                [[Sift sharedInstance] appendEvent:[SFEvent eventWithType:note.name path:nil fields:nil] withLocation:NO];
            }];
        }
    }
    return self;
}

@end
