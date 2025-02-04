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

// MARK: Mocks

+ (NSString *)mockNilStoredDeviceIFV {
    return nil;
}

+ (NSString *)mockChangedStoredDeviceIFV {
    return @"CHANGED-DEVICE-IFV";
}

+ (void)mockStoreDeviceIFV {}

@end
