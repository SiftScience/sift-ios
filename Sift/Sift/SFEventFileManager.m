// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "pthread.h"

#import "SFEventFileManager.h"

static NSString * const SFEventDirName = @"events";

static NSString *SFMakeEventDirName(NSString *identifier);

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

- (BOOL)removeEventStore:(NSString *)identifier purge:(BOOL)purge {
    pthread_rwlock_wrlock(&_lock);
    @try {
        SFEventFileStore *store = [_stores objectForKey:identifier];
        if (!store) {
            NSLog(@"Could not find event store for identifier to remove \"%@\"", identifier);
            return NO;
        }
        [_stores removeObjectForKey:identifier];
        if (purge) {
            return [store removeEventDir];
        } else {
            return YES;
        }
    }
    @finally {
        pthread_rwlock_unlock(&_lock);
    }
}

- (BOOL)useEventStore:(NSString *)identifier withBlock:(BOOL (^)(SFEventFileStore *store))block {
    pthread_rwlock_rdlock(&_lock);
    @try {
        // Create SFEventFileStore on-demand in case that a background NSURLSession wakes up the app, and the app did not properly initialize the SFEventFileManager...
        SFEventFileStore *store = [_stores objectForKey:identifier];
        if (!store) {
            // Upgrade to write lock.
            pthread_rwlock_unlock(&_lock);
            pthread_rwlock_wrlock(&_lock);
            store = [[SFEventFileStore alloc] initWithEventDirPath:[self eventDirPath:identifier]];
            if (store) {
                [_stores setObject:store forKey:identifier];
            }
            // We could downgrade back to read lock if that's a serious issue...
        }

        return block(store);
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
    return [_rootDirPath stringByAppendingPathComponent:SFMakeEventDirName(identifier)];
}

static NSString *SFMakeEventDirName(NSString *identifier) {
    if (identifier.length > 0) {
        return [NSString stringWithFormat:@"%@-%@", SFEventDirName, identifier];
    } else {
        return SFEventDirName;
    }
}

@end
