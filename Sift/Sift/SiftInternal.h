// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventsFileManager.h"

@interface Sift()

- (id)initWithIdentifier:(NSString *)identifier manager:(SFEventsFileManager *)manager;

NSData *createEvent(NSDictionary *data);

NSDictionary *readEvent(NSData *data, NSUInteger *location);

- (void)writeToCurrentEventsFile:(NSData *)event;

- (void)remindCheckCurrentEventsFile:(NSTimer *)timer;

- (void)checkCurrentEventsFile;

- (void)remindUploadEventsFiles:(NSTimer *)timer;

- (void)uploadEventsFiles;

// Visible for testing.
@property (readonly, nonatomic) SFEventsFileManager* manager;

// Test helpers.
@property (nonatomic, copy) void (^eventPersistedCallback)(NSFileHandle *currentEventsFile, NSData *event);
@property (nonatomic, copy) void (^uploadTaskCompletionCallback)(NSURLSession *session, NSURLSessionTask *task, NSError *error);

@end