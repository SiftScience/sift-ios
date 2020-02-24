// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SiftCompatibility.h"
#import "SiftDebug.h"

#import "SiftCircularBuffer.h"

@implementation SiftCircularBuffer {
    NSUInteger _size;
    NSUInteger _head;
    SF_GENERICS(NSMutableArray, id) *_items;
}

- (instancetype)initWithSize:(NSUInteger)size {
    self = [super init];
    if (self) {
        if (size <= 0) {
            SF_DEBUG(@"non-positive size: %lu", (unsigned long)size);
            self = nil;
            return nil;
        }
        _size = size;
        _head = 0;
        _items = [NSMutableArray new];
    }
    return self;
}

- (NSUInteger)count {
    return _items.count;
}

- (id)firstObject {
    if (_items.count < _size) {
        return _items.firstObject;
    } else {
        return [_items objectAtIndex:_head];
    }
}

- (id)lastObject {
    if (_items.count < _size) {
        return _items.lastObject;
    } else if (_head == 0) {
        return _items.lastObject;
    } else {
        return [_items objectAtIndex:(_head - 1)];
    }
}

- (id)append:(id)item {
    if (!item) {
        SF_DEBUG(@"You cannot append nil");
        return nil;
    } else if (_items.count < _size) {
        [_items addObject:item];
        return nil;
    } else {
        id replaced = [_items objectAtIndex:_head];
        [_items replaceObjectAtIndex:_head withObject:item];
        _head = (_head + 1) % _size;
        return replaced;
    }
}

- (NSArray *)shallowCopy {
    NSMutableArray *copy = [NSMutableArray new];
    if (_items.count < _size) {
        [copy addObjectsFromArray:_items];
    } else if (_head == 0) {
        [copy addObjectsFromArray:_items];
    } else {
        for (NSUInteger i = _head; i < _items.count; i++) {
            [copy addObject:_items[i]];
        }
        for (NSUInteger i = 0; i < _head; i++) {
            [copy addObject:_items[i]];
        }
    }
    return copy;
}

- (void)removeAllObjects {
    [_items removeAllObjects];
    _head = 0;
}

@end
