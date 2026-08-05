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
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };

    CFTypeRef result = NULL;
    SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);

    NSString *storedIFVString = nil;
    if (result) {
        NSDictionary *attributes = (__bridge_transfer NSDictionary *)result;
        NSData *data = attributes[(__bridge id)kSecValueData];
        storedIFVString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

        if (storedIFVString != nil && [self attributesNeedMigration:attributes]) {
            [self storeIFVString:storedIFVString];
        }
    }
    return storedIFVString;
}

+ (BOOL)attributesNeedMigration:(NSDictionary *)attributes {
    BOOL isDeviceOnly = [attributes[(__bridge id)kSecAttrAccessible]
                          isEqual:(__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly];
    BOOL isSynchronizable = [attributes[(__bridge id)kSecAttrSynchronizable] boolValue];
    return !isDeviceOnly || isSynchronizable;
}

+ (void)storeIFVString:(NSString *)ifv {
    NSDictionary *query = [self keychainQueryForIFV:ifv];
    SecItemDelete((__bridge CFDictionaryRef)query);
    SecItemAdd((__bridge CFDictionaryRef)query, NULL);
}

+ (NSDictionary *)keychainQueryForIFV:(NSString *)ifv {
    NSData *data = [ifv dataUsingEncoding:NSUTF8StringEncoding];
    return @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: kSiftVendorIFVKeychainKey,
        (__bridge id)kSecValueData: data,
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecAttrSynchronizable: (__bridge id)kCFBooleanFalse
    };
}

+ (NSString *)vendorIFVKeychainKey {
    return kSiftVendorIFVKeychainKey;
}

@end
