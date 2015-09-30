// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFMetrics.h"
#import "SFUtil.h"

#import "SFEventFile.h"
#import "SFEventFile+Internal.h"

static const int SFEventDataSizeLimit = UINT16_MAX;

BOOL SFEventFileAppendEvent(NSFileHandle *handle, NSDictionary *event) {
    NSData *data = SFEventFileCreateEventData(event);
    if (!data) {
        SFDebug(@"Could not serialize event");
        return NO;
    } else if (data.length <= 0) {
        SFDebug(@"Do not accept empty events: size=%ld", data.length);
        return NO;
    } else if (data.length > SFEventDataSizeLimit) {
        // Seriously? Are you really trying to send an event bigger than 64KB?
        SFDebug(@"Do not accept events bigger than %d bytes: size=%ld", SFEventDataSizeLimit, data.length);
        [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileDataSizeLimitExceededError];
        return NO;
    }

    uint16_t length = CFSwapInt16HostToLittle(data.length);
    [[SFMetrics sharedInstance] measure:SFMetricsKeyEventFileEventDataSize value:length];
    @try {
        [handle writeData:[NSData dataWithBytes:&length length:sizeof(length)]];
        [handle writeData:data];
    }
    @catch (NSException *exception) {
        SFDebug(@"Could not write to the current event file due to %@:%@\n%@", exception.name, exception.reason, exception.callStackSymbols);
        [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileWriteError];
        return NO;
    }

    return YES;
}

NSDictionary *SFEventFileReadLastEvent(NSFileHandle *handle) {
    if (!handle) {
        return nil;
    }

    int offset = 0;
    int length = 0;

    [handle seekToFileOffset:offset];
    uint16_t lengthBuffer;
    NSData *lengthData;
    while ((lengthData = [handle readDataOfLength:sizeof(lengthBuffer)]).length == sizeof(lengthBuffer)) {
        [lengthData getBytes:&lengthBuffer length:sizeof(lengthBuffer)];
        if ((length = CFSwapInt16LittleToHost(lengthBuffer)) <= 0) {
            SFDebug(@"Length should be positive (file corrupted?): %d", length);
            [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileCorruptionError];
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
    return SFEventFileReadEventData(data, &location);
}

NSData *SFEventFileCreateEventData(NSDictionary *event) {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:event options:0 error:&error];
    if (!data) {
        SFDebug(@"Could not serialize NSDictionary due to %@", [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileSerializationError];
        return nil;
    }
    return data;
}

NSDictionary *SFEventFileReadEventData(NSData *data, NSUInteger *location) {
    uint16_t lengthBuffer;
    NSRange range = {*location, sizeof(lengthBuffer)};
    [data getBytes:&lengthBuffer range:range];
    int length = CFSwapInt16LittleToHost(lengthBuffer);

    range.location += range.length;
    range.length = length;
    NSError *error;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[data subdataWithRange:range] options:0 error:&error];
    if (!event) {
        SFDebug(@"Could not parse JSON string due to %@", [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyEventFileDeserializationError];
        return nil;
    }

    *location = range.location + range.length;
    return event;
}
