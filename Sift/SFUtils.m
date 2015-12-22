// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "ctype.h"

#import "SFDebug.h"
#import "SFMetrics.h"
#import "SFUtils.h"

SFTimestamp SFCurrentTime(void) {
    return [[NSDate date] timeIntervalSince1970] * 1000.0;
}

NSString *SFCamelCaseToSnakeCase(NSString *camelCase) {
    const char *camel = [camelCase cStringUsingEncoding:NSASCIIStringEncoding];
    if (!camel) {
        SF_DEBUG(@"Cannot encode \"%@\" for ASCII", camelCase);
        return nil;
    }

    NSMutableString *snakeCase = [[NSMutableString alloc] initWithCapacity:(camelCase.length + 8)];  // Simple heuristic for capacity.
    char snake[512];  // 512 bytes should be enough most of the time...
    int i = 0;
    BOOL first = YES;
    while (*camel) {
        if (isupper(*camel) && !first) {
            snake[i++] = '_';
        }
        snake[i++] = tolower(*camel);

        // If we are close to the size of the buffer, flush it out.
        if (i >= sizeof(snake) - 8) {
            snake[i] = '\0';
            [snakeCase appendString:[NSString stringWithCString:snake encoding:NSASCIIStringEncoding]];
            i = 0;
        }

        camel++;
        first = NO;
    }
    snake[i] = '\0';
    [snakeCase appendString:[NSString stringWithCString:snake encoding:NSASCIIStringEncoding]];

    return snakeCase;
}

NSString *SFCacheDirPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

NSDictionary *SFFileAttrs(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error;
    NSDictionary *attributes = [manager attributesOfItemAtPath:path error:&error];
    if (!attributes) {
        SF_DEBUG(@"Could not get attributes of \"%@\" due to %@", path, [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
    }
    return attributes;
}

static BOOL SFFileDate(NSString *path, SEL getDate, NSTimeInterval *sinceNowOut, SFTimestamp *timestampOut) {
    NSDictionary *attributes = SFFileAttrs(path);
    if (!attributes) {
        return NO;
    }
    NSDate *(*func)(id, SEL) = (void *)[attributes methodForSelector:getDate];
    NSDate *date = func(attributes, getDate);
    NSTimeInterval sinceNow = -[date timeIntervalSinceNow];
    if (sinceNow < 0) {
        SF_DEBUG(@"%@ of \"%@\" is in the future: %@", NSStringFromSelector(getDate), path, date);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
        return NO;
    } else {
        if (sinceNowOut) {
            *sinceNowOut = sinceNow;
        }
        if (timestampOut) {
            *timestampOut = [date timeIntervalSince1970] * 1000;
        }
        return YES;
    }
}

BOOL SFFileExists(NSString *path) {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

BOOL SFFileCreationDate(NSString *path, NSTimeInterval *sinceNow) {
    return SFFileDate(path, @selector(fileCreationDate), sinceNow, nil);
}

BOOL SFFileModificationDate(NSString *path, NSTimeInterval *sinceNow) {
    return SFFileDate(path, @selector(fileModificationDate), sinceNow, nil);
}

BOOL SFFileModificationTimestamp(NSString *path, SFTimestamp *timestamp) {
    return SFFileDate(path, @selector(fileModificationDate), nil, timestamp);
}

NSArray *SFListDir(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [manager contentsOfDirectoryAtPath:path error:&error];
    if (!contents) {
        SF_DEBUG(@"Could not list contents of directory \"%@\" due to %@", path, [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
        return nil;
    }
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity:contents.count];
    for (NSString *fileName in contents) {
        [paths addObject:[path stringByAppendingPathComponent:fileName]];
    }
    return paths;
}

BOOL SFIsDirEmpty(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *contents = [manager contentsOfDirectoryAtPath:path error:&error];
    if (!contents) {
        SF_DEBUG(@"Could not list contents of directory \"%@\" due to %@", path, [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
        return NO;
    }
    return contents.count == 0;
}

BOOL SFTouchFilePath(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if ([manager fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (isDirectory) {
            SF_DEBUG(@"\"%@\" is a directory", path);
            [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
            return NO;
        } else {
            return YES;
        }
    } else {
        BOOL okay = [manager createFileAtPath:path contents:nil attributes:0];
        if (okay) {
            SF_DEBUG(@"Create file \"%@\"", path);
        } else {
            SF_DEBUG(@"Could not create file \"%@\"", path);
            [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
        }
        return okay;
    }
}

BOOL SFTouchDirPath(NSString *path) {
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory;
    if ([manager fileExistsAtPath:path isDirectory:&isDirectory]) {
        if (isDirectory) {
            return YES;
        } else {
            SF_DEBUG(@"\"%@\" is a file", path);
            [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
            return NO;
        }
    } else {
        NSError *error;
        BOOL okay = [manager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        if (okay) {
            SF_DEBUG(@"Create dir \"%@\"", path);
        } else {
            SF_DEBUG(@"Could not create dir \"%@\" due to %@", path, [error localizedDescription]);
            [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
        }
        return okay;
    }
}

BOOL SFRemoveFile(NSString *path) {
    NSError *error;
    BOOL okay = [[NSFileManager defaultManager] removeItemAtPath:path error:&error];
    if (okay) {
        SF_DEBUG(@"Remove \"%@\"", path);
    } else {
        SF_DEBUG(@"Could not remove \"%@\" due to %@", path, [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileOperationErrors];
    }
    return okay;
}

BOOL SFRemoveFilesInDir(NSString *path) {
    NSArray *filePaths = SFListDir(path);
    if (!filePaths) {
        return NO;
    }
    for (NSString *filePath in filePaths) {
        if (!SFRemoveFile(filePath)) {  // Fail fast.
            return NO;
        }
    }
    return YES;
}

id SFReadJsonFromFile(NSString *filePath) {
    NSData *data;
    @try {
        NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        data = [handle readDataToEndOfFile];
    }
    @catch (NSException *exception) {
        SF_DEBUG(@"Could not read from file \"%@\" due to %@:%@\n%@", filePath, exception.name, exception.reason, exception.callStackSymbols);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileIoErrors];
        return nil;
    }
    if (!data) {
        SF_DEBUG(@"Could not read contents of \"%@\"", filePath);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileIoErrors];
        return nil;
    }
    NSError *error;
    id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (!object) {
        SF_DEBUG(@"Could not deserialize JSON object from \"%@\" due to %@", filePath, [error localizedDescription]);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
    }
    return object;
}

BOOL SFWriteJsonToFile(id object, NSString *filePath) {
    NSError *error;
    NSData *data = [NSJSONSerialization dataWithJSONObject:object options:0 error:&error];
    if (!data) {
        SF_DEBUG(@"Could not serialize object");
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumMiscErrors];
        return NO;
    }
    @try {
        NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        [handle writeData:data];
        [handle closeFile];
    }
    @catch (NSException *exception) {
        SF_DEBUG(@"Could not write to file \"%@\" due to %@:%@\n%@", filePath, exception.name, exception.reason, exception.callStackSymbols);
        [[SFMetrics sharedInstance] count:SFMetricsKeyNumFileIoErrors];
        return NO;
    }
    return YES;
}
