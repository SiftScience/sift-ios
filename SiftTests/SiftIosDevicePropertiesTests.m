// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;
#import "XCTestCase+Swizzling.h"
#import "SiftKeychain+Testing.h"

#import "SiftDebug.h"

#import "SiftIosDeviceProperties.h"

@interface SiftIosDevicePropertiesTests : XCTestCase

@end

@implementation SiftIosDevicePropertiesTests

- (void)setup {
    Method storeIFV = class_getClassMethod([SiftKeychain class], @selector(storeIFVString:));
    Method mockStoreIFV = class_getClassMethod([self class], @selector(mockStoreDeviceIFV));
    
    [self swizzleMethod:storeIFV withMethod:mockStoreIFV];
}

- (void)tearDown {
    Method storeIFV = class_getClassMethod([SiftKeychain class], @selector(storeIFVString:));
    Method mockStoreIFV = class_getClassMethod([self class], @selector(mockStoreDeviceIFV));
    
    [self swizzleMethod:storeIFV withMethod:mockStoreIFV];
}

- (void)testCollect {
    NSDictionary *actual = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", actual);
    XCTAssertNotNil(actual);
}

- (void)testCoder {
    NSDictionary *expect, *actual;
    NSData *data;

    // Test empty object.
    expect = SFMakeEmptyIosDeviceProperties();
    XCTAssertEqual(0, expect.count);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }

    XCTAssertEqual(0, actual.count);
    XCTAssertEqualObjects(expect, actual);

    // Test object with a handful of properties.
    expect = SFMakeEmptyIosDeviceProperties();
    [expect setValue:@"test-string" forKey:@"app_name"];
    [expect setValue:@"" forKey:@"app_version"];
    [expect setValue:@[@"a", @"b", @"c"] forKey:@"evidence_files_present"];
    [expect setValue:@[] forKey:@"evidence_directories_writable"];
    XCTAssertEqual(4, expect.count);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }

    XCTAssertEqual(4, actual.count);
    XCTAssertEqualObjects(expect, actual);
}

- (void)testWithRandomData {
    NSDictionary *z = SFMakeEmptyIosDeviceProperties();  // Empty object.
    NSDictionary *p = [self generateRandomProperties];  // Random object 1.
    NSDictionary *q = [self generateRandomProperties];  // Random object 2.

    XCTAssertNotEqualObjects(z, p);
    XCTAssertNotEqualObjects(z, q);
    XCTAssertNotEqualObjects(p, q);

    NSDictionary *actual;
    NSData *data;

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:p requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:p];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    XCTAssertEqualObjects(p, actual);

    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:q requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:q];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
    XCTAssertEqualObjects(q, actual);
}

- (void)testMacCatalyst {
    NSDictionary *actual = SFCollectIosDeviceProperties();
    SF_DEBUG(@"Collect device properties: %@", actual);
    XCTAssertNotNil(actual);
    
    NSString *deviceName = actual[@"device_system_name"];
    #if !TARGET_OS_MACCATALYST
        XCTAssertFalse([deviceName containsString:@"Mac"]);
    #else
        XCTAssertTrue([deviceName containsString:@"Mac"]);
    #endif
}

- (void)testProcessDeviceIFV_nilDeviceIFV {
    Method getStoredDeviceIFV = class_getClassMethod([SiftKeychain class], @selector(getStoredIFVString));
    Method mockGetStoredDeviceIFV = class_getClassMethod([self class], @selector(mockNilStoredDeviceIFV));
    Method deviceIdentifier = class_getInstanceMethod([UIDevice class], @selector(identifierForVendor));
    Method mockDeviceIdentifier = class_getClassMethod([self class], @selector(mockNilDeviceIdentifier));
    
    [self swizzleMethod:getStoredDeviceIFV withMethod:mockGetStoredDeviceIFV];
    [self swizzleMethod:deviceIdentifier withMethod:mockDeviceIdentifier];
    
    NSString *actual = SFCollectIosDeviceProperties()[@"initial_device_ifv"];

    XCTAssertNil(actual);
    
    [self swizzleMethod:mockGetStoredDeviceIFV withMethod:getStoredDeviceIFV];
    [self swizzleMethod:mockDeviceIdentifier withMethod:deviceIdentifier];
}

- (void)testProcessDeviceIFV_nilStoredDeviceIFV {
    Method getStoredDeviceIFV = class_getClassMethod([SiftKeychain class], @selector(getStoredIFVString));
    Method mockGetStoredDeviceIFV = class_getClassMethod([self class], @selector(mockNilStoredDeviceIFV));

    [self swizzleMethod:getStoredDeviceIFV withMethod:mockGetStoredDeviceIFV];

    NSString *deviceIFV = [[UIDevice currentDevice] identifierForVendor].UUIDString;
    NSString *actual = SFCollectIosDeviceProperties()[@"initial_device_ifv"];

    XCTAssertEqualObjects(actual, deviceIFV);
    
    [self swizzleMethod:mockGetStoredDeviceIFV withMethod:getStoredDeviceIFV];
}

- (void)testProcessDeviceIFV_changedDeviceIFV {
    Method getStoredDeviceIFV = class_getClassMethod([SiftKeychain class], @selector(getStoredIFVString));
    Method mockGetStoredDeviceIFV = class_getClassMethod([self class], @selector(mockChangedStoredDeviceIFV));

    [self swizzleMethod:getStoredDeviceIFV withMethod:mockGetStoredDeviceIFV];

    NSString *actual = SFCollectIosDeviceProperties()[@"initial_device_ifv"];

    XCTAssertEqual(actual, @"CHANGED-DEVICE-IFV");
    
    [self swizzleMethod:mockGetStoredDeviceIFV withMethod:getStoredDeviceIFV];
}

// MARK: Helpers

- (NSDictionary *)generateRandomProperties {
    NSMutableDictionary *properties = SFMakeEmptyIosDeviceProperties();
    [properties setValue:[self generateRandomString] forKey:@"app_name"];
    [properties setValue:[self generateRandomString] forKey:@"app_version"];
    [properties setValue:[self generateRandomArray] forKey:@"evidence_files_present"];
    [properties setValue:[self generateRandomArray] forKey:@"evidence_directories_writable"];
    return properties;
}

- (NSString *)generateRandomString {
    char buffer[128];
    int n = arc4random_uniform(sizeof(buffer));
    buffer[n--] = '\0';
    while (n >= 0) {
        buffer[n--] = 'a' + arc4random_uniform(26);
    }
    return [NSString stringWithCString:buffer encoding:NSASCIIStringEncoding];
}

- (NSArray *)generateRandomArray {
    NSMutableArray *strings = [NSMutableArray new];
    int n = arc4random_uniform(128);
    while (n-- > 0) {
        [strings addObject:[self generateRandomString]];
    }
    return strings;
}

// MARK: Mocks

+ (NSString *)mockNilDeviceIdentifier {
    return nil;
}

+ (NSString *)mockNilStoredDeviceIFV {
    return nil;
}

+ (NSString *)mockChangedStoredDeviceIFV {
    return @"CHANGED-DEVICE-IFV";
}

+ (void)mockStoreDeviceIFV {}
@end
