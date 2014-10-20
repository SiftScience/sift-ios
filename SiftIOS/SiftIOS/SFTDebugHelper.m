//
//  SFTDebugHelper.m
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//



#import "SFTDebugHelper.h"
#import "SFTConstants.h"


@implementation SFTDebugHelper

+(void) logIfDebug:(NSString*)format, ... {
    if (SFTDEBUG) {
        va_list args;
        va_start(args, format);
        NSLogv(format, args);
        va_end(args);
    }
}

@end
