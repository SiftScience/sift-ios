//
//  SiftKeychain.m
//  Sift
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import "SiftKeychain.h"
#import "SiftDebug.h"
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

    if (!result) {
        return nil;
    }
    NSDictionary *attributes = (__bridge_transfer NSDictionary *)result;
    return [self processStoredIFVAttributes:attributes];
}

+ (NSString *)processStoredIFVAttributes:(NSDictionary *)attributes {
    NSData *data = attributes[(__bridge id)kSecValueData];
    NSString *storedIFVString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];

    if (storedIFVString != nil && [self attributesNeedMigration:attributes]) {
        [self migrateStoredIFV:storedIFVString];
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
    OSStatus addStatus = [self addIFV:ifv];
    if (addStatus == errSecDuplicateItem) {
        // An item already exists under this account even though the caller determined
        // no usable value was stored (e.g. getStoredIFVString found data that failed to
        // decode as UTF8). Clear it and retry once rather than failing silently forever.
        [self deleteStoredIFV];
        addStatus = [self addIFV:ifv];
    }
    if (addStatus != errSecSuccess) {
        SF_DEBUG(@"Failed to store initial_device_ifv keychain item, status=%d", (int)addStatus);
    }
}

+ (OSStatus)addIFV:(NSString *)ifv {
    return SecItemAdd((__bridge CFDictionaryRef)[self keychainQueryForIFV:ifv], NULL);
}

+ (void)migrateStoredIFV:(NSString *)ifv {
    [self deleteStoredIFV];
    [self storeIFVString:ifv];
}

+ (void)deleteStoredIFV {
    OSStatus deleteStatus = SecItemDelete((__bridge CFDictionaryRef)[self ifvDeleteQuery]);
    if (deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound) {
        SF_DEBUG(@"Failed to delete existing initial_device_ifv keychain item, status=%d", (int)deleteStatus);
    }
}

+ (NSDictionary *)ifvDeleteQuery {
    return @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: kSiftVendorIFVKeychainKey
    };
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
