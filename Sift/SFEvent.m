// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFUtils.h"

#import "SFEvent.h"

@implementation SFEvent

+ (SFEvent *)eventWithType:(NSString *)type path:(NSString *)path fields:(NSDictionary *)fields {
    SFEvent *event = [SFEvent new];
    if (type) {
        event.type = type;
    }
    if (path) {
        event.path = path;
    }
    if (fields) {
        event.fields = fields;
    }
    return event;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _time = SFCurrentTime();
        _type = nil;
        _path = nil;
        _userId = nil;
        _fields = nil;
        _deviceProperties = nil;
        _metrics = nil;
    }
    return self;
}

@end
