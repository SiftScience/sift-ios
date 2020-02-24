// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SiftCompatibility.h"

/**
 * Append-only circular buffer.
 *
 * Note that this class is not thread-safe.
 */
@interface SF_GENERICS(SiftCircularBuffer, __covariant ObjectType) : NSObject

- (instancetype)initWithSize:(NSUInteger)size;

@property (readonly) NSUInteger size;
@property (readonly) NSUInteger count;

@property (nonatomic, readonly) SF_GENERICS_TYPE(ObjectType) firstObject;
@property (nonatomic, readonly) SF_GENERICS_TYPE(ObjectType) lastObject;

/** Append an item to the buffer and return the replaced item (or nil if no item is replaced). */
- (SF_GENERICS_TYPE(ObjectType))append:(SF_GENERICS_TYPE(ObjectType))item;

- (SF_GENERICS(NSArray, ObjectType) *)shallowCopy;

- (void)removeAllObjects;

@end
