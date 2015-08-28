//
//  Sift.h
//  Sift
//
//  Created by Che-Liang Chiou on 8/25/15.
//  Copyright © 2015 Sift Science. All rights reserved.
//

@import Foundation;


typedef void (^CompletionHandler)(NSURLSession *session, NSURLSessionTask *task, NSError *error);


// Use case:
//   [[Sift sharedInstance] track:@"http://www.example.com" title:@"This is a title string"];
@interface Sift : NSObject <NSURLSessionDelegate, NSURLSessionTaskDelegate, NSURLSessionDataDelegate>

// You use the global shared instance of Sift object.
+ (Sift *)sharedInstance;

- (id)initWithIdentifier:(NSString *)identifier;

// TODO: Manage life-cycle of NSURLSession object.
@property NSURLSession *session;

// The remote server that we are sending beacons to.
@property NSString *tracker;

// A Sift object is stateful in the sense that it tracks the referer URL.
@property NSString *referer;

// Useful for testing (and maybe error reporting?).
@property (strong) CompletionHandler completionHandler;

// Track a page activity (technically, this does a GET on tracker URL).
- (void)track:(NSString *)url title:(NSString *)title;

// Collect information and construct the tracker URL.
+ (NSString *)track:(NSString *)url title:(NSString *)title tracker:(NSString *)tracker referer:(NSString *)referer;

@end