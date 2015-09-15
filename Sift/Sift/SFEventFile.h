// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

BOOL SFEventFileAppendEvent(NSFileHandle *handle, NSDictionary *event);

NSDictionary *SFEventFileReadLastEvent(NSFileHandle *handle);