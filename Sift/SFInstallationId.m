// Copyright (c) 2016 Sift Science. All rights reserved.

@import Foundation;

#import "SFDebug.h"

#import "SFInstallationId.h"

NSString *SFGetInstallationId(void) {
    NSMutableDictionary *keychainItemBase = [NSMutableDictionary new];
    keychainItemBase[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
    keychainItemBase[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAlways;
    keychainItemBase[(__bridge id)kSecAttrAccount] = @"sift_installation_id";
    keychainItemBase[(__bridge id)kSecAttrService] = @"siftscience.keychain";

    NSMutableDictionary *keychainItem;

    keychainItem = [NSMutableDictionary dictionaryWithDictionary:keychainItemBase];
    keychainItem[(__bridge id)kSecReturnAttributes] = (__bridge id)kCFBooleanTrue;
    keychainItem[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    CFDictionaryRef dict = nil;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainItem, (CFTypeRef *)&dict) == noErr) {
        NSDictionary *item = (__bridge_transfer NSDictionary *)dict;
        NSData *data = item[(__bridge id)kSecValueData];
        NSString *persistentUniqueId = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        SF_DEBUG(@"Return persistent unique ID: %@", persistentUniqueId);
        return persistentUniqueId;
    }

    NSString *randomUuid = [[NSUUID UUID] UUIDString];
    SF_DEBUG(@"Create new persistent unique ID: %@", randomUuid);

    keychainItem = [NSMutableDictionary dictionaryWithDictionary:keychainItemBase];
    keychainItem[(__bridge id)kSecValueData] = [randomUuid dataUsingEncoding:NSUTF8StringEncoding];
    SecItemAdd((__bridge CFDictionaryRef)keychainItem, NULL);

    return randomUuid;
}