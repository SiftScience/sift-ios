// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

/** Debug output that can be turned on/off by NDEBUG. */
#ifdef NDEBUG
#define SF_DEBUG(...)
#else
#define SF_DEBUG(FORMAT, ...) NSLog(@"%s:%d " FORMAT, __FUNCTION__, __LINE__, ## __VA_ARGS__)
#endif
