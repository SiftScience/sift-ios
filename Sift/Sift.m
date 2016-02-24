// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"
#import "Sift.h"

@implementation Sift

+ (instancetype)sharedInstance {
    static Sift *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [Sift new];
    });
    return instance;
}

// TODO(clchiou): Really implement Sift object.

@end
