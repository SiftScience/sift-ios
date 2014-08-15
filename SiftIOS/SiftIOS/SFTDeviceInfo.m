//
//  SFTDeviceInfo.m
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import "SFTDeviceInfo.h"
#import <UIKit/UIKit.h>

@implementation SFTDeviceInfo

// TODO(lrandroid): ensure these are available per-iOS version

-(NSString*) identifierForVendor {
    return [[[UIDevice currentDevice] identifierForVendor] UUIDString];
}

-(NSString*) deviceSystemVersion {
    return [[UIDevice currentDevice] systemVersion];
}
            
-(NSString*) deviceModel {
    return [[UIDevice currentDevice] model];
}

-(NSString*) deviceLocalizedModel {
    return [[UIDevice currentDevice] localizedModel];
}

-(NSString*) deviceName {
    return [[UIDevice currentDevice] name];
}

-(NSString*) deviceSystemName {
    return [[UIDevice currentDevice] systemName];
}

-(NSString*) defaultLanguage {
    NSArray* languages = [NSLocale preferredLanguages];
    if (languages.count > 0) {
        return languages[0];
    }
    return nil;
}

-(BOOL) jailbreakStatus {
    #if TARGET_IPHONE_SIMULATOR
    return NO;
    #else
    FILE *f = fopen("/bin/bash", "r");
    fclose(f);
    return f ? YES : NO;
    #endif
}

@end
