// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

/**
 * Heterogeneous-typed dictionary.
 *
 * Each heterogeneous-typed dictionary instance has a entryTypes dictionary
 * specifying what keys and what type of values it takes.
 */
@interface SFHtDictionary : NSObject <NSCoding>

- (instancetype)initWithEntryTypes:(NSDictionary<NSString *, Class> *)entryTypes;

- (BOOL)setEntry:(NSString *)key value:(id)value;

@property NSDictionary<NSString *, Class> *entryTypes;
@property NSMutableDictionary *entries;

@end
