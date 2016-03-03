// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "Sift.h"

#import "SFAppEventsReporter.h"

// Whitelist of notification prefixes that a fraud analyst might care.
//
// TODO(clchiou): Add more notifications here (and before you add them,
// make sure a fraud analyst would be able to understand their meaning).
static NSString * const SFNotificationNamePrefixes[] = {
    @"UIApplicationDidEnterBackground",
    @"UIApplicationDidBecomeActive",
    nil,
};

@implementation SFAppEventsReporter {
    NSOperationQueue *_queue;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _queue = [NSOperationQueue new];
        [[NSNotificationCenter defaultCenter] addObserverForName:nil object:nil queue:_queue usingBlock:^(NSNotification *note) {
            for (int i = 0; SFNotificationNamePrefixes[i]; i++) {
                if ([note.name hasPrefix:SFNotificationNamePrefixes[i]]) {
                    SF_DEBUG(@"Notified with \"%@\"", note.name);
                    [[Sift sharedInstance] appendEvent:[SFEvent eventWithType:note.name path:nil fields:nil]];
                    break;
                }
            }
        }];
    }
    return self;
}

@end
