//
//  Util.m
//  SiftIOS
//
//  Created by Joey Robinson on 8/14/14.
//  Copyright (c) 2014 Sift Science. All rights reserved.
//

#import "SFTUtil.h"
#import <Foundation/NSJSONSerialization.h>
#import <CommonCrypto/CommonDigest.h>

@implementation SFTUtil

+(NSString*) dictionaryToJSON: (NSDictionary*) dict {
    NSError* error;
    NSData* jsonData = [NSJSONSerialization dataWithJSONObject:dict
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    
    if (! jsonData) {
        NSLog(@"Error converting dictionary to JSON: %@", error);
        return nil;
    } else {
        NSString* json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        return json;
    }
}

+(NSString*) hashString: (NSString*) text {
    unsigned char hashBuffer[CC_SHA256_DIGEST_LENGTH];
    if (CC_SHA256([text UTF8String], (int) [text length], hashBuffer)) {
        NSData* sha2 = [NSData dataWithBytes:hashBuffer length:CC_SHA256_DIGEST_LENGTH];
        return [NSString stringWithUTF8String: [sha2 bytes]];
    }
    return nil;
}

@end
