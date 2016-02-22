// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import UIKit;

#import "SFDebug.h"
#import "SFEvent.h"
#import "SFAppEventReporter.h"
#import "Sift.h"

static NSString * const SFAppEventType = @"$app";

// Whitelist of notification prefixes that a fraud analyst might care.
//
// TODO(clchiou): Add more notifications here (and before you add them,
// make sure a fraud analyst would be able to understand their meaning).
static NSString * const SFNotificationNamePrefixes[] = {
    @"UIApplicationDidEnterBackground",
    @"UIApplicationDidBecomeActive",
    nil,
};

@implementation SFAppEventReporter

- (instancetype)initWithQueue:(NSOperationQueue *)queue {
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserverForName:nil object:nil queue:queue usingBlock:^(NSNotification *note) {
            for (int i = 0; SFNotificationNamePrefixes[i]; i++) {
                if ([note.name hasPrefix:SFNotificationNamePrefixes[i]]) {
                    SFSendAppEvent(note.name);
                    break;
                }
            }
        }];
    }
    return self;
}

static void SFSendAppEvent(NSString *name) {
    SF_DEBUG(@"Notified with \"%@\"", name);
    NSDictionary *fields = @{@"name": name};
    Sift *sift = [Sift sharedInstance];
    [sift appendEvent:[SFEvent eventWithPath:nil mobileEventType:SFAppEventType userId:sift.userId fields:fields]];
}

@end
