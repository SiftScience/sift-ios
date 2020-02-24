// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

/** Debug output that can be turned on/off by SF_DEBUG_ENABLE macro. */
#ifdef SF_DEBUG_ENABLE
#define SF_DEBUG(FORMAT, ...) NSLog(@"%s:%d " FORMAT, __FUNCTION__, __LINE__, ## __VA_ARGS__)
#else
#define SF_DEBUG(...)
#endif

/** Log messages to console that (we think) are important to the SDK users. */
#ifdef SF_INFO_ENABLE
#define SF_IMPORTANT(FORMAT, ...) NSLog(@"%s:%d " FORMAT, __FUNCTION__, __LINE__, ## __VA_ARGS__)
#else
#define SF_IMPORTANT(...)
#endif
