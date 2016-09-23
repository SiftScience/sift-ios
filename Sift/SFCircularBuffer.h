// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

/**
 * Append-only circular buffer.
 *
 * Note that this class is not thread-safe.
 */
@interface SFCircularBuffer<__covariant ObjectType> : NSObject

- (instancetype)initWithSize:(NSUInteger)size;

@property (readonly) NSUInteger size;
@property (readonly) NSUInteger count;

@property (nonatomic, readonly) ObjectType firstObject;
@property (nonatomic, readonly) ObjectType lastObject;

/** Append an item to the buffer and return the replaced item (or nil if no item is replaced). */
- (ObjectType)append:(ObjectType)item;

- (NSArray<ObjectType> *)shallowCopy;

- (void)removeAllObjects;

@end
