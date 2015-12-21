// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFRecordIo.h"
#import "SFMetrics.h"
#import "SFUtils.h"

#import "SFEvent.h"
#import "SFEvent+Utils.h"

BOOL SFEventIsEmptyUserId(NSString *userId) {
    return !userId || [userId isEqualToString:@""];
}

@implementation SFEvent

+ (SFEvent *)eventWithPath:(NSString *)path mobileEventType:(NSString *)mobileEventType userId:(NSString *)userId fields:(NSDictionary *)fields {
    SFEvent *event = [SFEvent new];
    if (path) {
        event.path = path;
    }
    if (mobileEventType) {
        event.mobileEventType = mobileEventType;
    }
    if (userId) {
        event.userId = userId;
    }
    if (fields) {
        event.fields = fields;
    }
    return event;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _time = SFTimestampMillis();
        _path = nil;
        _mobileEventType = nil;
        _userId = nil;
        _fields = nil;
        _deviceProperties = nil;
        _metrics = nil;
    }
    return self;
}

- (NSDictionary *)makeEvent {
    NSAssert(!SFEventIsEmptyUserId(_userId), @"userId is _NOT_ optional");

    NSMutableDictionary *event = [NSMutableDictionary new];
    [event setObject:[NSNumber numberWithInteger:_time] forKey:@"time"];
    if (_path) {
        [event setObject:_path forKey:@"path"];
    }
    if (_mobileEventType) {
        [event setObject:_mobileEventType forKey:@"mobile_event_type"];
    }
    [event setObject:_userId forKey:@"user_id"];
    if (_fields) {
        [event setObject:_fields forKey:@"fields"];
    }
    if (_deviceProperties) {
        [event setObject:_deviceProperties forKey:@"device_properties"];
    }
    if (_metrics) {
        [event setObject:_metrics forKey:@"metrics"];
    }
    return event;
}

@end

BOOL SFEventCompare(NSDictionary *event1, NSDictionary *event2) {
    NSMutableDictionary *e1 = [NSMutableDictionary dictionaryWithDictionary:event1];
    NSMutableDictionary *e2 = [NSMutableDictionary dictionaryWithDictionary:event2];
    [e1 removeObjectForKey:@"time"];
    [e2 removeObjectForKey:@"time"];
    return [e1 isEqualToDictionary:e2];
}

static NSData *SFHeader;
static NSData *SFFooter;
static NSData *SFComma;

@interface SFRecordIoToListRequestConverter ()

- (BOOL)writeListRequestWithBlock:(BOOL (^)())block;

@end

@implementation SFRecordIoToListRequestConverter {
    NSFileHandle *_listRequest;
    BOOL _firstRecord;
}

- (instancetype)init {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SFHeader = [@"{\"data\":[" dataUsingEncoding:NSASCIIStringEncoding];
        SFFooter = [@"]}" dataUsingEncoding:NSASCIIStringEncoding];
        SFComma = [@"," dataUsingEncoding:NSASCIIStringEncoding];
    });
    self = [super init];
    if (self) {
        _listRequest = nil;
        _firstRecord = true;
    }
    return self;
}

- (BOOL)writeListRequestWithBlock:(BOOL (^)())block {
    if (!_listRequest) {
        SF_DEBUG(@"This converter is not started yet");
        return NO;
    }
    @try {
        return block();
    }
    @catch (NSException *exception) {
        SF_DEBUG(@"Could not write to list request file due to %@:%@\n%@", exception.name, exception.reason, exception.callStackSymbols);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileIoErrors];
        return NO;
    }
}

- (BOOL)start:(NSFileHandle *)listRequest {
    if (_listRequest) {
        SF_DEBUG(@"This converter has already been started");
        return NO;
    }
    if (!listRequest) {
        SF_DEBUG(@"listRequest is nil");
        return NO;
    }
    _listRequest = listRequest;
    return [self writeListRequestWithBlock:^BOOL (){
        [_listRequest writeData:SFHeader];
        return YES;
    }];
}

- (BOOL)convert:(NSFileHandle *)recordIo {
    if (!recordIo) {
        SF_DEBUG(@"recordIo is nil");
        return NO;
    }
    return [self writeListRequestWithBlock:^BOOL () {
        NSData *data;
        while ((data = SFRecordIoReadRecordData(recordIo)) != nil) {
            if (!_firstRecord) {
                [_listRequest writeData:SFComma];
            }
            _firstRecord = false;
            [_listRequest writeData:data];
        }
        return YES;
    }];
}

- (BOOL)end {
    if (!_listRequest) {
        SF_DEBUG(@"This converter is not started yet");
        return NO;
    }
    BOOL okay = [self writeListRequestWithBlock:^BOOL (){
        [_listRequest writeData:SFFooter];
        return YES;
    }];
    if (okay) {
        _listRequest = nil;
        _firstRecord = true;
    }
    return okay;
}

@end
