// Copyright (c) 2015 Sift Science. All rights reserved.

@import Foundation;

#import "SFConfig.h"

@implementation NSValue (SFCONfig)

+ (instancetype)valueWithSFConfig:(SFConfig)value {
    return [self valueWithBytes:&value objCType:@encode(SFConfig)];
}

- (SFConfig)sfConfigValue {
    SFConfig value;
    [self getValue:&value];
    return value;
}

@end
