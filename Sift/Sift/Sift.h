// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

@interface Sift : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

// Return the shared global instance of the Sift object.
+ (Sift *)sharedInstance;

// Track an event.
- (void)event:(NSDictionary *)data;

// Post tracked events to this API endpoint (writable for testing).
@property NSString *tracker;

@end