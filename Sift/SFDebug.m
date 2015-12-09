// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"

void SFDebugWithLoc(const char *func, int line, NSString *format, ...) {
    NSString *formatWithLoc = [NSString stringWithFormat:@"%s:%d %@", func, line, format];
    va_list args;
    va_start(args, format);
    NSLogv(formatWithLoc, args);
    va_end(args);
}