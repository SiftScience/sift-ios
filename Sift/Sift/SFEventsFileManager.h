// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

@interface SFEventsFileManager : NSObject

+ (SFEventsFileManager *)sharedInstance;

- (id)initWithEventsDirName:(NSString *)eventsDirName;

- (BOOL)maybeRotateCurrentEventsFile:(BOOL)forceRotating;

- (void)processEventsFiles:(void (^)(NSFileManager *, NSArray *))reader;

- (void)writeCurrentEventsFile:(void (^)(NSFileHandle *))writer;

- (void)removeEventsDir;

@end
