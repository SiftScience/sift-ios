// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFEventFile.h"
#import "SFEventFile+Internal.h"

BOOL SFEventFileAppendEvent(NSFileHandle *handle, NSDictionary *event) {
    NSData *data = SFEventFileCreateEventData(event);
    if (!data) {
        NSLog(@"Could not serialize event");
        return NO;
    }

    // TODO(clchiou): Also compute a checksum (CRC32?).
    uint32_t length = CFSwapInt32HostToLittle((uint32_t)data.length);
    @try {
        [handle writeData:[NSData dataWithBytes:&length length:sizeof(length)]];
        [handle writeData:data];
    }
    @catch (NSException *exception) {
        NSLog(@"Could not write to the current event file due to %@:%@\n%@", exception.name, exception.reason, exception.callStackSymbols);
        return NO;
    }

    return YES;
}

// TODO(clchiou): We could append length when writing to file, and make this faster.
NSDictionary *SFEventFileReadLastEvent(NSFileHandle *handle) {
    if (!handle) {
        return nil;
    }
    [handle seekToFileOffset:0];
    uint32_t offset = 0;
    uint32_t length = 0;
    while (true) {
        NSData *lengthData = [handle readDataOfLength:sizeof(length)];
        if (lengthData.length < sizeof(length)) {
            break;
        } else if (length > 0) {
            offset += sizeof(length) + length;
        }
        [lengthData getBytes:&length length:sizeof(length)];
        length = CFSwapInt32LittleToHost(length);
        [handle seekToFileOffset:(offset + sizeof(length) + length)];
    }
    if (!length) {
        return nil;
    }
    [handle seekToFileOffset:offset];
    NSData *data = [handle readDataOfLength:(sizeof(length) + length)];
    NSUInteger location = 0;
    return SFEventFileReadEventData(data, &location);
}

NSData *SFEventFileCreateEventData(NSDictionary *event) {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:event options:0 error:&error];
    if (!data) {
        NSLog(@"Could not serialize dictionary due to %@", [error localizedDescription]);
        return nil;
    }
    return data;
}

NSDictionary *SFEventFileReadEventData(NSData *data, NSUInteger *location) {
    uint32_t length;
    NSRange range = {*location, sizeof(length)};
    [data getBytes:&length range:range];
    length = CFSwapInt32LittleToHost(length);
    
    range.location += range.length;
    range.length = length;
    NSError *error;
    NSDictionary *event = [NSJSONSerialization JSONObjectWithData:[data subdataWithRange:range] options:0 error:&error];
    if (!event) {
        NSLog(@"Could not parse dictionary due to %@", [error localizedDescription]);
        return nil;
    }
    
    *location = range.location + range.length;
    return event;
}
