// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFMetrics.h"

#import "SFRecordIo.h"
#import "SFRecordIo+Private.h"

static const int SFRecordDataSizeLimit = UINT16_MAX;

BOOL SFRecordIoAppendRecord(NSFileHandle *handle, NSDictionary *record) {
    NSData *data = SFRecordIoCreateRecordData(record);
    if (!data) {
        SFDebug(@"Could not serialize record");
        return NO;
    } else if (data.length <= 0) {
        SFDebug(@"Do not accept empty records: size=%ld", data.length);
        return NO;
    } else if (data.length > SFRecordDataSizeLimit) {
        // Seriously? Are you really trying to send a record bigger than 64KB?
        SFDebug(@"Do not accept records bigger than %d bytes: size=%ld", SFRecordDataSizeLimit, data.length);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyRecordIoDataSizeLimitExceededError];
        return NO;
    }

    uint16_t length = CFSwapInt16HostToLittle(data.length);
    [[SFMetrics sharedMetrics] measure:SFMetricsKeyRecordIoDataSize value:length];
    @try {
        [handle writeData:[NSData dataWithBytes:&length length:sizeof(length)]];
        [handle writeData:data];
    }
    @catch (NSException *exception) {
        SFDebug(@"Could not write to the current event file due to %@:%@\n%@", exception.name, exception.reason, exception.callStackSymbols);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyRecordIoWriteError];
        return NO;
    }

    return YES;
}

NSDictionary *SFRecordIoReadLastRecord(NSFileHandle *handle) {
    assert(handle);

    int offset = 0;
    int length = 0;

    [handle seekToFileOffset:offset];
    uint16_t lengthBuffer;
    NSData *lengthData;
    while ((lengthData = [handle readDataOfLength:sizeof(lengthBuffer)]).length == sizeof(lengthBuffer)) {
        [lengthData getBytes:&lengthBuffer length:sizeof(lengthBuffer)];
        if ((length = CFSwapInt16LittleToHost(lengthBuffer)) <= 0) {
            SFDebug(@"Length should be positive (file corrupted?): %d", length);
            [[SFMetrics sharedMetrics] count:SFMetricsKeyRecordIoCorruptionError];
            return nil;
        }
        offset += sizeof(lengthBuffer) + length;
        [handle seekToFileOffset:offset];
    }
    if (!length) {
        return nil;
    }

    [handle seekToFileOffset:(offset - sizeof(lengthBuffer) - length)];
    NSData *data = [handle readDataOfLength:(sizeof(lengthBuffer) + length)];
    NSUInteger location = 0;
    return SFRecordIoReadRecordData(data, &location);
}

NSData *SFRecordIoCreateRecordData(NSDictionary *record) {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:0 error:&error];
    if (!data) {
        SFDebug(@"Could not serialize NSDictionary due to %@", [error localizedDescription]);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyRecordIoSerializationError];
        return nil;
    }
    return data;
}

NSDictionary *SFRecordIoReadRecordData(NSData *data, NSUInteger *location) {
    uint16_t lengthBuffer;
    NSRange range = {*location, sizeof(lengthBuffer)};
    [data getBytes:&lengthBuffer range:range];
    int length = CFSwapInt16LittleToHost(lengthBuffer);

    range.location += range.length;
    range.length = length;
    NSError *error;
    NSDictionary *record = [NSJSONSerialization JSONObjectWithData:[data subdataWithRange:range] options:0 error:&error];
    if (!record) {
        SFDebug(@"Could not parse JSON string due to %@", [error localizedDescription]);
        [[SFMetrics sharedMetrics] count:SFMetricsKeyRecordIoDeserializationError];
        return nil;
    }

    *location = range.location + range.length;
    return record;
}
