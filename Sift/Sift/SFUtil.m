// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFUtil.h"

NSString *SFCacheDirPath(void) {
    return [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}