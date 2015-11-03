// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFRecordIo.h"
#import "SFMetrics.h"

#import "SFEvent.h"

NSDictionary *SFEventMakeEvent(NSInteger time, NSString *path, NSString *mobileEventType, NSString *userId, NSDictionary *fields) {
    NSMutableDictionary *event = [NSMutableDictionary new];
    [event setObject:[NSNumber numberWithInteger:time] forKey:@"time"];
    if (path) {
        [event setObject:path forKey:@"path"];
    }
    if (mobileEventType) {
        [event setObject:mobileEventType forKey:@"mobile_event_type"];
    }
    if (userId) {
        [event setObject:userId forKey:@"user_id"];
    }
    if (fields) {
        [event setObject:fields forKey:@"fields"];
    }
    return event;
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
        SFDebug(@"This converter is not started yet");
        return NO;
    }
    @try {
        return block();
    }
    @catch (NSException *exception) {
        SFDebug(@"Could not write to list request file due to %@:%@\n%@", exception.name, exception.reason, exception.callStackSymbols);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyNumFileIoErrors];
        return NO;
    }
}

- (BOOL)start:(NSFileHandle *)listRequest {
    if (_listRequest) {
        SFDebug(@"This converter has already been started");
        return NO;
    }
    if (!listRequest) {
        SFDebug(@"listRequest is nil");
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
        SFDebug(@"recordIo is nil");
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
        SFDebug(@"This converter is not started yet");
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
