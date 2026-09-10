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

static NSString *capturedStoreIFVArg = nil;
static NSInteger addIFVCallCount = 0;
static BOOL deleteStoredIFVWasCalled = NO;

- (void)setUp {
    addIFVCallCount = 0;
    deleteStoredIFVWasCalled = NO;

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

- (void)testIfvDeleteQuery_containsOnlyClassAndAccount {
    NSDictionary *query = [SiftKeychain ifvDeleteQuery];

    XCTAssertEqual(query.count, 2u);
    XCTAssertEqualObjects(query[(__bridge id)kSecClass], (__bridge id)kSecClassGenericPassword);
    XCTAssertEqualObjects(query[(__bridge id)kSecAttrAccount], [SiftKeychain vendorIFVKeychainKey]);
    XCTAssertNil(query[(__bridge id)kSecAttrAccessible],
                 @"delete query must not filter by accessibility - it would fail to match legacy items");
    XCTAssertNil(query[(__bridge id)kSecValueData]);
    XCTAssertNil(query[(__bridge id)kSecAttrSynchronizable]);
}

- (void)testProcessStoredIFVAttributes_migratesLegacyAttributes {
    NSString *legacyValue = @"LEGACY-IFV";
    NSDictionary *legacyAttributes = @{
        (__bridge id)kSecValueData: [legacyValue dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleWhenUnlocked,
        (__bridge id)kSecAttrSynchronizable: @NO
    };

    NSString *capturedArg = nil;
    NSString *result = [self processAttributes:legacyAttributes capturingMigrateArg:&capturedArg];

    XCTAssertEqualObjects(result, legacyValue);
    XCTAssertEqualObjects(capturedArg, legacyValue,
                           @"migration should re-store (delete+re-add) the legacy item");
}

- (void)testProcessStoredIFVAttributes_doesNotMigrateWhenAlreadyDeviceOnly {
    NSString *value = @"CURRENT-IFV";
    NSDictionary *upToDateAttributes = @{
        (__bridge id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding],
        (__bridge id)kSecAttrAccessible: (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        (__bridge id)kSecAttrSynchronizable: @NO
    };

    NSString *capturedArg = nil;
    NSString *result = [self processAttributes:upToDateAttributes capturingMigrateArg:&capturedArg];

    XCTAssertEqualObjects(result, value);
    XCTAssertNil(capturedArg, @"should not re-store when attributes are already up to date");
}

- (void)testStoreIFVString_selfHealsOnDuplicateItem {
    [self storeIFVWithAddMock:@selector(mockAddIFVDuplicateThenSuccess:)];

    XCTAssertTrue(deleteStoredIFVWasCalled, @"a duplicate-item add should trigger a delete before retrying");
    XCTAssertEqual(addIFVCallCount, 2, @"add should be retried exactly once after the delete");
}

- (void)testStoreIFVString_doesNotDeleteOnSuccessfulAdd {
    [self storeIFVWithAddMock:@selector(mockAddIFVAlwaysSuccess:)];

    XCTAssertFalse(deleteStoredIFVWasCalled, @"a successful add should not trigger a delete");
    XCTAssertEqual(addIFVCallCount, 1, @"add should not be retried when it succeeds the first time");
}

// MARK: Helpers

- (void)storeIFVWithAddMock:(SEL)addMockSelector {
    // setUp mocks storeIFVString: to a no-op for the rest of the suite; un-mock it here
    // since it's the method under test.
    Method storeIFV = class_getClassMethod([SiftKeychain class], @selector(storeIFVString:));
    Method mockStoreIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockStoreDeviceIFV));
    [self swizzleMethod:storeIFV withMethod:mockStoreIFV];

    Method addIFV = class_getClassMethod([SiftKeychain class], @selector(addIFV:));
    Method mockAddIFV = class_getClassMethod([SiftKeychainTests class], addMockSelector);
    [self swizzleMethod:addIFV withMethod:mockAddIFV];

    Method deleteStoredIFV = class_getClassMethod([SiftKeychain class], @selector(deleteStoredIFV));
    Method mockDeleteStoredIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockDeleteStoredIFVSpy));
    [self swizzleMethod:deleteStoredIFV withMethod:mockDeleteStoredIFV];

    @try {
        [SiftKeychain storeIFVString:@"SOME-IFV"];
    } @finally {
        [self swizzleMethod:mockAddIFV withMethod:addIFV];
        [self swizzleMethod:mockDeleteStoredIFV withMethod:deleteStoredIFV];
        [self swizzleMethod:mockStoreIFV withMethod:storeIFV];
    }
}

- (NSString *)processAttributes:(NSDictionary *)attributes capturingMigrateArg:(NSString **)capturedArg {
    capturedStoreIFVArg = nil;
    Method migrateIFV = class_getClassMethod([SiftKeychain class], @selector(migrateStoredIFV:));
    Method mockMigrateIFV = class_getClassMethod([SiftKeychainTests class], @selector(mockCaptureStoreIFV:));
    [self swizzleMethod:migrateIFV withMethod:mockMigrateIFV];

    NSString *result = nil;
    @try {
        result = [SiftKeychain processStoredIFVAttributes:attributes];
    } @finally {
        [self swizzleMethod:mockMigrateIFV withMethod:migrateIFV];
    }

    if (capturedArg) {
        *capturedArg = capturedStoreIFVArg;
    }
    return result;
}

// MARK: Mocks

+ (NSString *)mockNilStoredDeviceIFV {
    return nil;
}

+ (NSString *)mockChangedStoredDeviceIFV {
    return @"CHANGED-DEVICE-IFV";
}

+ (void)mockStoreDeviceIFV {}

+ (void)mockCaptureStoreIFV:(NSString *)ifv {
    capturedStoreIFVArg = ifv;
}

+ (OSStatus)mockAddIFVDuplicateThenSuccess:(NSString *)ifv {
    addIFVCallCount++;
    return (addIFVCallCount == 1) ? errSecDuplicateItem : errSecSuccess;
}

+ (OSStatus)mockAddIFVAlwaysSuccess:(NSString *)ifv {
    addIFVCallCount++;
    return errSecSuccess;
}

+ (void)mockDeleteStoredIFVSpy {
    deleteStoredIFVWasCalled = YES;
}

@end
