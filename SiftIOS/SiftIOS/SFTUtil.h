//
//  Util.h
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface SFTUtil : NSObject

/**
 * Returns a JSON NSString* representation of the given dictionary.
 */
+(NSString*) dictionaryToJSON: (NSDictionary*) dict;

/**
 * Returns the SHA-256 hash of an NSString*.
 */
+(NSString*) hashString: (NSString*) text;
@end
