// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;
@import CoreLocation;

#import "SFEvent.h"

typedef void (^OnAugmentCompletion)(SFEvent *);

@interface SFLocation : NSObject<CLLocationManagerDelegate>

/** Augment an event with location data and call you on completion. */
- (void)augment:(SFEvent *)event onCompletion:(OnAugmentCompletion)block;

@end
