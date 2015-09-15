// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

NSData *SFEventFileCreateEventData(NSDictionary *event);

NSDictionary *SFEventFileReadEventData(NSData *data, NSUInteger *location);