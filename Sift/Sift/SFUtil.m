// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "SFUtil.h"

NSInteger SFTimestampMillis(void) {
    return [[NSDate date] timeIntervalSince1970] * 1000.0;
}

NSString *SFCacheDirPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

BOOL SFTouchFilePath(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if ([manager fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (isDirectory) {
            SFDebug(@"\"%@\" is a directory", path);
            return NO;
        } else {
            return YES;
        }
    } else {
        BOOL okay = [manager createFileAtPath:path contents:nil attributes:0];
        if (okay) {
            SFDebug(@"Create file \"%@\"", path);
        } else {
            SFDebug(@"Could not reate file \"%@\"", path);
        }
        return okay;
    }
}

id SFReadJsonFromFile(NSString *filePath) {
    NSData *data;
    @try {
        NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        data = [handle readDataToEndOfFile];
    }
    @catch (NSException *exception) {
        SFDebug(@"Could not read from file \"%@\" due to %@:%@\n%@", filePath, exception.name, exception.reason, exception.callStackSymbols);
        return nil;
    }
    if (!data) {
        SFDebug(@"Could not read contents of \"%@\"", filePath);
        return nil;
    }
    NSError *error;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!object) {
        SFDebug(@"Could not deserialize JSON object from \"%@\" due to %@", filePath, [error localizedDescription]);
    }
    return object;
}

BOOL SFWriteJsonToFile(id object, NSString *filePath) {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    if (!data) {
        SFDebug(@"Could not serialize object");
        return NO;
    }
    @try {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        [handle writeData:data];
        [handle closeFile];
    }
    @catch (NSException *exception) {
        SFDebug(@"Could not write to file \"%@\" due to %@:%@\n%@", filePath, exception.name, exception.reason, exception.callStackSymbols);
        return NO;
    }
    return YES;
}