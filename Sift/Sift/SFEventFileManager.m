// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "pthread.h"

#import "SFEventFileManager.h"

static NSString *EVENT_DIR_NAME = @"events";

@interface SFEventFileManager ()

- (NSString *)eventDirPath:(NSString *)identifier;

@end

@implementation SFEventFileManager {
    NSString *_rootDirPath;
    NSMutableDictionary *_stores;
    pthread_rwlock_t _lock;  // Using a RW lock is easier than dispatch_barrier_async at the moment...
}

- (id)initWithRootDir:(NSString *)rootDirPath {
    self = [super init];
    if (self) {
        _rootDirPath = rootDirPath;
        _stores = [NSMutableDictionary new];
        pthread_rwlock_init(&_lock, NULL);

        NSError *error;
        if (![[NSFileManager defaultManager] createDirectoryAtPath:_rootDirPath withIntermediateDirectories:YES attributes:nil error:&error]) {
            NSLog(@"Could not create root dir \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
            self = nil;
            return nil;
        }
    }
    return self;
}

- (void)dealloc {
    pthread_rwlock_destroy(&_lock);
    //[super dealloc];  // Provided by compiler!
}

- (BOOL)addEventStore:(NSString *)identifier {
    pthread_rwlock_wrlock(&_lock);
    @try {
        if ([_stores objectForKey:identifier]) {
            // Would not overwrite the event store...
            return YES;
        }
        
        SFEventFileStore *store = [[SFEventFileStore alloc] initWithEventDirPath:[self eventDirPath:identifier]];
        if (!store) {
            return NO;
        }
        
        [_stores setObject:store forKey:identifier];
        
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)removeEventStore:(NSString *)identifier {
    pthread_rwlock_wrlock(&_lock);
    @try {
        SFEventFileStore *store = [_stores objectForKey:identifier];
        if (!store) {
            NSLog(@"Could not find event store for identifier to remove \"%@\"", identifier);
            return NO;
        }
        [_stores removeObjectForKey:identifier];
        return YES;
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)accessEventStore:(NSString *)identifier block:(BOOL (^)(SFEventFileStore *store))block {
    pthread_rwlock_rdlock(&_lock);
    @try {
        // TODO(clchiou): Should we create SFEventFileStore on-demand? (If on the suspend-resume path that the app is not fully initialized...)
        return block([_stores objectForKey:identifier]);
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (void)removeRootDir {
    pthread_rwlock_wrlock(&_lock);
    @try {
        [_stores removeAllObjects];
        
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtPath:_rootDirPath error:&error]) {
            NSLog(@"Could not remove root dir \"%@\" due to %@", _rootDirPath, [error localizedDescription]);
        }
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (NSString *)eventDirPath:(NSString *)identifier {
    return [_rootDirPath stringByAppendingPathComponent:SFEventDirName(identifier)];
}

static NSString *SFEventDirName(NSString *identifier) {
    if (identifier.length > 0) {
        return [NSString stringWithFormat:@"%@-%@", EVENT_DIR_NAME, identifier];
    } else {
        return EVENT_DIR_NAME;
    }
}

@end
