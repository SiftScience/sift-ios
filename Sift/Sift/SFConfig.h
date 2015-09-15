// Copyright © 2015 Sift Science. All rights reserved.

@import Foundation;

struct _SFConfig {
    BOOL trackEventDifferenceOnly;

    NSTimeInterval rotateCurrentEventFileInterval;
    NSTimeInterval rotateCurrentEventFileIfOlderThan;
    unsigned long long rotateCurrentEventFileIfLargerThan;

    NSTimeInterval uploadEventFilesInterval;
};

typedef struct _SFConfig SFConfig;

@interface NSValue (SFConfig)

+ (instancetype)valueWithSFConfig:(SFConfig)value;

@property (readonly) SFConfig sfConfigValue;

@end