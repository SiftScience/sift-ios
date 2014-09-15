//
//  SFTDeviceInfo.m
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import "SFTDeviceInfo.h"
#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "SFTFieldNames.h"
#import "SFTDebugHelper.h"

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

-(NSDictionary*) lastLocation {
    [SFTDebugHelper logIfDebug: @"%@", @"Checking for last location."];
    if([CLLocationManager locationServicesEnabled] &&
       [CLLocationManager authorizationStatus] == kCLAuthorizationStatusAuthorized) {
        // user has enabled location services, return location
        [SFTDebugHelper logIfDebug: @"%@", @"Location services enabled, gathering location."];
        CLLocationManager* manager = [CLLocationManager new];
        CLLocation* location = [manager location];
        [SFTDebugHelper logIfDebug: @"%@", @"Location obtained."];
        if (location) {
            NSMutableDictionary* dict = [NSMutableDictionary new];
            [SFTDebugHelper logIfDebug: @"%@", @"Created dict."];
            CLLocationCoordinate2D coordinate = [location coordinate];
            [SFTDebugHelper logIfDebug: @"%@ %@", LAST_LOCATION_LATITUDE, [NSNumber numberWithDouble:coordinate.latitude]];
            [dict setValue:[NSNumber numberWithDouble:coordinate.latitude] forKey:LAST_LOCATION_LATITUDE];
            [SFTDebugHelper logIfDebug: @"%@", @"Added latitude."];
            [dict setValue:[NSNumber numberWithDouble:coordinate.longitude] forKey:LAST_LOCATION_LONGITUDE];
            [SFTDebugHelper logIfDebug: @"%@", @"Added longitude."];
            [dict setValue:[NSNumber numberWithDouble:[location altitude]] forKey:LAST_LOCATION_ALTITUDE];
            [SFTDebugHelper logIfDebug: @"%@", @"Added altitude."];
            [SFTDebugHelper logIfDebug: @"%@", @"Location successfully gathered."];
            return dict;
        }
        [SFTDebugHelper logIfDebug: @"%@", @"Location is nil."];
    }
    [SFTDebugHelper logIfDebug: @"%@", @"Location services disabled."];
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
