//
//  SFTSiftDeviceInfo.h
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFTSiftDeviceInfo : NSObject

/// @description Creates and initializes a new SFTSiftDeviceInfo object with a user id and api key
-(id) initWithUser: (NSString*) aUser apiKey: (NSString*) anApiKey;

/** @description Requests a device info update to be sent to Sift.
 *
 * This call is non-blocking and runs on a background thead.
 */
-(BOOL) updateInfo;

@end
