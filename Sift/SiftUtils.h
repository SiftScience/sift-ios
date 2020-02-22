// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

/** Generic helper functions. */

/** Short hand of NSAssert(false, ...) */
#define SFFail() NSAssert(false, @"SFFail() at %s:%d", __FUNCTION__, __LINE__)

typedef uint64_t SFTimestamp;

/** @return the current time stamp in milliseconds. */
SFTimestamp SFCurrentTime(void);

/** @return snake case string, e.g., "camelCase" to "camel_case". */
NSString *SFCamelCaseToSnakeCase(NSString *camelCase);

/** @return the path to a cache directory. */
NSString *SFCacheDirPath(void);
