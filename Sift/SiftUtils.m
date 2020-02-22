// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "ctype.h"

#import "SiftDebug.h"
#import "SiftUtils.h"

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
        // Determinte whether we should insert an '_' character.
        if (isupper(*camel) && !first) {
            // Handle "isCAMEL" -> "is_camel" case.
            // We may look back one character because !first is true.
            if (islower(camel[-1])) {
                snake[i++] = '_';
            }
            // Handle "SFCamel" -> "sf_camel" case.
            // We may look ahead one character because *camel is not '\0'.
            else if (islower(camel[1])) {
                snake[i++] = '_';
            }
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
