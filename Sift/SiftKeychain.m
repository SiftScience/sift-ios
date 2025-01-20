//
//  SiftKeychain.m
//  Sift
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import "SiftKeychain.h"
@import Security;

static NSString* kSiftVendorIFVKeychainKey = @"com.sift.initial_device_ifv";

@implementation SiftKeychain

+ (NSString *)processDeviceIFV:(NSString *)ifv {
    NSString *storedIFVString = [self getStoredIFVString];
    if (storedIFVString == nil && ifv == nil) {
        return nil;
    }

    if (storedIFVString == nil) {
        [self storeIFVString:ifv];
        return ifv;
    }

    return storedIFVString;
}

+ (NSString *)getStoredIFVString {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: kSiftVendorIFVKeychainKey,
        (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };

    CFTypeRef result = NULL;
    SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    NSString *storedIFVString = nil;
    if (result) {
        NSData *data = (__bridge_transfer NSData *)result;
        storedIFVString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return storedIFVString;
}

+ (void)storeIFVString:(NSString *)ifv {
    NSData *data = [ifv dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: kSiftVendorIFVKeychainKey,
        (__bridge id)kSecValueData: data
    };

    SecItemDelete((__bridge CFDictionaryRef)query);
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
}

@end
