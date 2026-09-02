//
//  SiftKeychainE2ETests.m
//  SiftE2ETests
//
//  Black-box end-to-end tests for SiftKeychain, run against the real Keychain
//  inside a hosted XCTest bundle (SiftE2ETestHost). No swizzling: every call
//  through SiftKeychain's public API here exercises real SecItemAdd /
//  SecItemCopyMatching / SecItemDelete.
//

#import <XCTest/XCTest.h>
#import "SiftKeychain.h"
#import "SiftKeychain+Testing.h"

@interface SiftKeychainE2ETests : XCTestCase

@end

@implementation SiftKeychainE2ETests

- (void)setUp {
    [self rawDeleteStoredItem];
}

- (void)tearDown {
    [self rawDeleteStoredItem];
}

#pragma mark - processDeviceIFV: test cases

- (void)testProcessDeviceIFV_firstRun_storesAndReturnsGivenIFV {
    NSDictionary *attributesBeforeCall = [self rawReadStoredAttributes];
    XCTAssertNil(attributesBeforeCall, @"nothing should be stored before this test's call");

    NSString *result = [SiftKeychain processDeviceIFV:@"NEW-IFV"];
    XCTAssertEqualObjects(result, @"NEW-IFV");

    NSDictionary *attributesAfterCall = [self rawReadStoredAttributes];
    XCTAssertNotNil(attributesAfterCall, @"processDeviceIFV: should have persisted a Keychain item");
    XCTAssertEqualObjects(attributesAfterCall[(__bridge id)kSecValueData],
                           [@"NEW-IFV" dataUsingEncoding:NSUTF8StringEncoding]);
    XCTAssertEqualObjects(attributesAfterCall[(__bridge id)kSecAttrAccessible],
                           (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly);
    XCTAssertFalse([attributesAfterCall[(__bridge id)kSecAttrSynchronizable] boolValue],
                    @"stored item should not be synchronizable");
}

- (void)testProcessDeviceIFV_subsequentRun_returnsStoredValueRegardlessOfNewIFV {
    NSString *firstResult = [SiftKeychain processDeviceIFV:@"ORIGINAL-IFV"];
    XCTAssertEqualObjects(firstResult, @"ORIGINAL-IFV");

    NSString *secondResult = [SiftKeychain processDeviceIFV:@"DIFFERENT-IFV"];
    XCTAssertEqualObjects(secondResult, @"ORIGINAL-IFV",
                           @"a subsequent call should return the already-stored value, ignoring the new one");

    NSDictionary *attributesAfterSecondCall = [self rawReadStoredAttributes];
    XCTAssertNotNil(attributesAfterSecondCall, @"the stored item should still be present");
    XCTAssertEqualObjects(attributesAfterSecondCall[(__bridge id)kSecValueData],
                           [@"ORIGINAL-IFV" dataUsingEncoding:NSUTF8StringEncoding],
                           @"the stored value should remain unchanged by the second call");
}

- (void)testProcessDeviceIFV_nilIFVAndNothingStored_returnsNilAndStoresNothing {
    NSDictionary *attributesBeforeCall = [self rawReadStoredAttributes];
    XCTAssertNil(attributesBeforeCall, @"nothing should be stored before this test's call");

    NSString *result = [SiftKeychain processDeviceIFV:nil];
    XCTAssertNil(result, @"a nil IFV with nothing stored should return nil");

    NSDictionary *attributesAfterCall = [self rawReadStoredAttributes];
    XCTAssertNil(attributesAfterCall, @"processDeviceIFV: with a nil IFV should not have stored anything");
}

- (void)testProcessDeviceIFV_migratesLegacyStoredItem {
    [self rawStoreLegacyItemWithValue:@"LEGACY-IFV"];

    NSDictionary *attributesBeforeMigration = [self rawReadStoredAttributes];
    XCTAssertNotNil(attributesBeforeMigration, @"the raw legacy-shaped item should be visible before migration");
    XCTAssertNotEqualObjects(attributesBeforeMigration[(__bridge id)kSecAttrAccessible],
                              (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                              @"precondition guard: a freshly seeded legacy item must not already have the "
                              @"post-migration accessibility, or this test would be a tautology");

    NSString *result = [SiftKeychain processDeviceIFV:@"IGNORED-NEW-IFV"];
    XCTAssertEqualObjects(result, @"LEGACY-IFV",
                           @"the existing stored value should win over a new IFV, unchanged by migration");

    NSDictionary *attributesAfterMigration = [self rawReadStoredAttributes];
    XCTAssertNotNil(attributesAfterMigration, @"the migrated item should still be present");
    XCTAssertEqualObjects(attributesAfterMigration[(__bridge id)kSecValueData],
                           [@"LEGACY-IFV" dataUsingEncoding:NSUTF8StringEncoding],
                           @"the stored value should remain LEGACY-IFV after migration");
    XCTAssertEqualObjects(attributesAfterMigration[(__bridge id)kSecAttrAccessible],
                           (__bridge id)kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                           @"the item should be re-stored as device-only after migration");
    XCTAssertFalse([attributesAfterMigration[(__bridge id)kSecAttrSynchronizable] boolValue],
                    @"the migrated item should not be synchronizable");
}

#pragma mark - Raw Keychain helpers

// Deletes any item under SiftKeychain's account, ignoring errSecItemNotFound. Used by
// setUp/tearDown so real Keychain state never leaks between tests or across Simulator runs.
- (void)rawDeleteStoredItem {
    NSDictionary *deleteQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: [SiftKeychain vendorIFVKeychainKey]
    };
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)deleteQuery);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        XCTFail(@"raw cleanup SecItemDelete failed with status=%d", (int)status);
    }
}

// Builds its own SecItemAdd query with only kSecClass + kSecAttrAccount + kSecValueData -
// no kSecAttrAccessible, no kSecAttrSynchronizable - matching the actual pre-migration
// (MSUE-220) query shape, not a synthetic one.
- (void)rawStoreLegacyItemWithValue:(NSString *)value {
    NSDictionary *addQuery = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: [SiftKeychain vendorIFVKeychainKey],
        (__bridge id)kSecValueData: [value dataUsingEncoding:NSUTF8StringEncoding]
    };
    OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
    XCTAssertEqual(status, errSecSuccess, @"raw legacy-shaped SecItemAdd should succeed");
}

// Raw SecItemCopyMatching returning kSecValueData + kSecAttrAccessible +
// kSecAttrSynchronizable for assertions. Returns nil if nothing is stored (errSecItemNotFound);
// any other unexpected status fails the test rather than silently masquerading as absence.
- (NSDictionary *)rawReadStoredAttributes {
    NSDictionary *query = @{
        (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrAccount: [SiftKeychain vendorIFVKeychainKey],
        (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecReturnAttributes: (__bridge id)kCFBooleanTrue,
        (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
    };
    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecItemNotFound) {
        return nil;
    }
    if (status != errSecSuccess) {
        XCTFail(@"raw read SecItemCopyMatching failed with unexpected status=%d", (int)status);
        return nil;
    }
    return (__bridge_transfer NSDictionary *)result;
}

@end
