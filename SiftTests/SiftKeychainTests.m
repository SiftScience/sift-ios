//
//  SiftKeychainTests.m
//  SiftTests
//
//  Created by Anton Poluboiarynov on 20.01.2025.
//  Copyright © 2025 Sift Science. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "XCTestCase+Swizzling.h"
#import "SiftKeychain+Testing.h"

@interface SiftKeychainTests : XCTestCase

@end

@implementation SiftKeychainTests

- (void)setup {
    Method storeIFV = class_getClassMethod([SiftKeychain class], @selector(storeIFVString:));
    Method mockStoreIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockStoreDeviceIFV));
    
    [self swizzleMethod:storeIFV withMethod:mockStoreIFV];
}

- (void)tearDown {
    Method storeIFV = class_getClassMethod([SiftKeychain class], @selector(storeIFVString:));
    Method mockStoreIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockStoreDeviceIFV));
    
    [self swizzleMethod:storeIFV withMethod:mockStoreIFV];    
}

- (void)testProcessDeviceIFV_nilDeviceIFV {
    Method getStoredDeviceIFV = class_getClassMethod([SiftKeychain class], @selector(getStoredIFVString));
    Method mockGetStoredDeviceIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockNilStoredDeviceIFV));

    [self swizzleMethod:getStoredDeviceIFV withMethod:mockGetStoredDeviceIFV];

    NSString *actual = [SiftKeychain processDeviceIFV:nil];

    XCTAssertNil(actual);
    
    [self swizzleMethod:mockGetStoredDeviceIFV withMethod:getStoredDeviceIFV];
}

- (void)testProcessDeviceIFV_nilStoredDeviceIFV {
    Method getStoredDeviceIFV = class_getClassMethod([SiftKeychain class], @selector(getStoredIFVString));
    Method mockGetStoredDeviceIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockNilStoredDeviceIFV));

    [self swizzleMethod:getStoredDeviceIFV withMethod:mockGetStoredDeviceIFV];

    NSString *deviceIFV = @"DEVICE-IFV";
    NSString *actual = [SiftKeychain processDeviceIFV:deviceIFV];

    XCTAssertEqual(actual, deviceIFV);
    
    [self swizzleMethod:mockGetStoredDeviceIFV withMethod:getStoredDeviceIFV];
}

- (void)testProcessDeviceIFV_changedDeviceIFV {
    Method getStoredDeviceIFV = class_getClassMethod([SiftKeychain class], @selector(getStoredIFVString));
    Method mockGetStoredDeviceIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockChangedStoredDeviceIFV));

    [self swizzleMethod:getStoredDeviceIFV withMethod:mockGetStoredDeviceIFV];

    NSString *deviceIFV = @"DEVICE-IFV";
    NSString *actual = [SiftKeychain processDeviceIFV:deviceIFV];

    XCTAssertEqual(actual, @"CHANGED-DEVICE-IFV");
    
    [self swizzleMethod:mockGetStoredDeviceIFV withMethod:getStoredDeviceIFV];
}

- (void)testKeychainQueryForIFV_setsDeviceOnlyAccessibilityAndNotSynchronizable {
    NSString *ifv = @"TEST-DEVICE-ONLY-IFV";
    NSDictionary *query = [SiftKeychain keychainQueryForIFV:ifv];

    XCTAssertEqualObjects(query[(__bridge id)kSecAttrAccount], [SiftKeychain vendorIFVKeychainKey]);
    XCTAssertEqualObjects(query[(__bridge id)kSecValueData], [ifv dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(query[(__bridge id)kSecAttrAccessible],
                           (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly);
    XCTAssertEqualObjects(query[(__bridge id)kSecAttrSynchronizable], @NO);
}

- (void)testAttributesNeedMigration_returnsNoWhenAlreadyDeviceOnlyAndNotSynchronizable {
    NSDictionary *attributes = @{
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecAttrSynchronizable: @NO
    };

    XCTAssertFalse([SiftKeychain attributesNeedMigration:attributes]);
}

- (void)testAttributesNeedMigration_returnsYesWhenAccessibleIsMissingOrNotDeviceOnly {
    NSDictionary *missingAccessible = @{
        (__bridge id)kSecAttrSynchronizable: @NO
    };
    NSDictionary *legacyAccessible = @{
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked,
        (__bridge id)kSecAttrSynchronizable: @NO
    };

    XCTAssertTrue([SiftKeychain attributesNeedMigration:missingAccessible]);
    XCTAssertTrue([SiftKeychain attributesNeedMigration:legacyAccessible]);
}

- (void)testAttributesNeedMigration_returnsYesWhenSynchronizable {
    NSDictionary *attributes = @{
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecAttrSynchronizable: @YES
    };

    XCTAssertTrue([SiftKeychain attributesNeedMigration:attributes]);
}

// MARK: Mocks

+ (NSString *)mockNilStoredDeviceIFV {
    return nil;
}

+ (NSString *)mockChangedStoredDeviceIFV {
    return @"CHANGED-DEVICE-IFV";
}

+ (void)mockStoreDeviceIFV {}

@end
