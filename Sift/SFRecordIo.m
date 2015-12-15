// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFMetrics.h"

#import "SFRecordIo.h"

static NSData *SFSerializeRecord(NSDictionary *record);

static NSDictionary *SFDeserializeRecordData(NSData *data);

static BOOL SFReadUint16(NSFileHandle *handle, int *output);

static BOOL SFReadLength(NSFileHandle *handle, int *output);

static const int SFRecordDataSizeLimit = UINT16_MAX;

BOOL SFRecordIoAppendRecord(NSFileHandle *handle, NSDictionary *record) {
    NSData *data = SFSerializeRecord(record);
    if (!data) {
        SF_DEBUG(@"Could not serialize record");
        return NO;
    } else if (data.length <= 0) {
        SF_DEBUG(@"Do not accept empty records: size=%ld", (long)data.length);
        return NO;
    } else if (data.length > SFRecordDataSizeLimit) {
        // Seriously? Are you really trying to send a record bigger than 64KB?
        SF_DEBUG(@"Do not accept records bigger than %d bytes: size=%ld", SFRecordDataSizeLimit, (long)data.length);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
        return NO;
    }

    [[SFMetrics sharedInstance] measure:SFMetricsKeyRecordSize value:data.length];
    uint16_t length = CFSwapInt16HostToLittle(data.length);
    @try {
        [handle writeData:[NSData dataWithBytes:&length length:sizeof(length)]];
        [handle writeData:data];
        [handle writeData:[NSData dataWithBytes:&length length:sizeof(length)]];  // This makes read-last easier.
    }
    @catch (NSException *exception) {
        SF_DEBUG(@"Could not write to the current record file due to %@:%@\n%@", exception.name, exception.reason, exception.callStackSymbols);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileIoErrors];
        return NO;
    }

    return YES;
}

NSDictionary *SFRecordIoReadRecord(NSFileHandle *handle) {
    return SFDeserializeRecordData(SFRecordIoReadRecordData(handle));
}

NSData *SFRecordIoReadRecordData(NSFileHandle *handle) {
    if (!handle) {
        return nil;
    }

    int length;
    if (!SFReadLength(handle, &length)) {
        return nil;
    }

    NSData *data = [handle readDataOfLength:length];
    if (!data) {
        return nil;
    }

    int length2;
    if (!SFReadLength(handle, &length2)) {
        return nil;
    }
    if (length != length2) {
        SF_DEBUG(@"Lengths do not match (file corrupted?): %d != %d", length, length2);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumDataCorruptionErrors];
        return nil;
    }

    return data;
}

NSDictionary *SFRecordIoReadLastRecord(NSFileHandle *handle) {
    return SFDeserializeRecordData(SFRecordIoReadLastRecordData(handle));
}

NSData *SFRecordIoReadLastRecordData(NSFileHandle *handle) {
    if (!handle) {
        return nil;
    }

    const int lengthSize = sizeof(uint16_t);

    unsigned long long size = [handle seekToEndOfFile];

    if (size < lengthSize) {
        return nil;
    }
    [handle seekToFileOffset:(size - lengthSize)];

    int length2;
    if (!SFReadLength(handle, &length2)) {
        return nil;
    }

    if (size < lengthSize * 2 + length2) {
        return nil;
    }
    [handle seekToFileOffset:(size - (lengthSize * 2 + length2))];

    int length;
    if (!SFReadLength(handle, &length)) {
        return nil;
    }
    if (length != length2) {
        SF_DEBUG(@"Lengths do not match (file corrupted?): %d != %d", length, length2);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumDataCorruptionErrors];
        return nil;
    }

    return [handle readDataOfLength:length];
}

static NSData *SFSerializeRecord(NSDictionary *record) {
    if (!record) {
        return nil;
    }
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:record options:0 error:&error];
    if (!data) {
        SF_DEBUG(@"Could not serialize NSDictionary due to %@", [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
        return nil;
    }
    return data;
}

static NSDictionary *SFDeserializeRecordData(NSData *data) {
    if (!data) {
        return nil;
    }
    NSError *error;
    NSDictionary *record = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!record) {
        SF_DEBUG(@"Could not parse JSON string due to %@", [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
        return nil;
    }
    return record;
}

static BOOL SFReadUint16(NSFileHandle *handle, int *output) {
    uint16_t data;
    NSData *buffer = [handle readDataOfLength:sizeof(data)];
    if (buffer.length != sizeof(data)) {
        return NO;
    }
    [buffer getBytes:&data length:sizeof(data)];
    *output = CFSwapInt16LittleToHost(data);
    return YES;
}

static BOOL SFReadLength(NSFileHandle *handle, int *output) {
    int length;
    if (!SFReadUint16(handle, &length)) {
        return NO;
    }
    if (length <= 0) {
        SF_DEBUG(@"Length should be positive (file corrupted?): %d", length);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumDataCorruptionErrors];
        return NO;
    }
    *output = length;
    return YES;
}
