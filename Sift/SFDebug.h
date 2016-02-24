// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

/** Debug output that can be turned on/off by NDEBUG. */
#ifdef DEBUG
#define SF_DEBUG(FORMAT, ...) NSLog(@"%s:%d " FORMAT, __FUNCTION__, __LINE__, ## __VA_ARGS__)
#else
#define SF_DEBUG(...)
#endif
