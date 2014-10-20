//
//  SFTDeviceInfo.h
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFTDeviceInfo : NSObject

-(NSString*) identifierForVendor;
-(NSString*) deviceSystemVersion;
-(NSString*) deviceModel;
-(NSString*) deviceLocalizedModel;
-(NSString*) deviceName;
-(NSString*) deviceSystemName;
-(NSString*) defaultLanguage;
-(NSDictionary*) lastLocation;
-(BOOL) jailbreakStatus;

@end
