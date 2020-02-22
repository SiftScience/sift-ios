// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

@import CoreLocation;
@import UIKit;

#import "SiftIosAppState.h"
#import "SiftIosDeviceProperties.h"

#import "SiftEvent.h"
#import "SiftEvent+Private.h"

@interface SiftEventTests : XCTestCase

@end

@implementation SiftEventTests

- (void)testCollect {
    CLLocationManager *locationManager = [CLLocationManager new];

    SiftEvent *event = [SiftEvent new];
    event.iosAppState = SFCollectIosAppState(locationManager, @"SiftViewController");
    event.iosDeviceProperties = SFCollectIosDeviceProperties();

    NSData *listRequest = [SiftEvent listRequest:@[event]];

    // Verify JSON object generated on simulator.

    id object = [NSJSONSerialization JSONObjectWithData:listRequest options:0 error:nil];
    XCTAssert([object isKindOfClass:NSDictionary.class]);
    NSDictionary *jsonObject = object;
    XCTAssertEqual(1, jsonObject.count);
    XCTAssert([jsonObject objectForKey:@"data"]);

    XCTAssert([[jsonObject objectForKey:@"data"] isKindOfClass:NSArray.class]);
    NSArray *data = [jsonObject objectForKey:@"data"];
    XCTAssertEqual(1, data.count);

    XCTAssert([data.firstObject isKindOfClass:NSDictionary.class]);
    NSDictionary *actual = data.firstObject;

    XCTAssertEqualObjects([NSNumber numberWithUnsignedLongLong:event.time], [actual objectForKey:@"time"]);

    XCTAssertEqualObjects(event.installationId, [actual objectForKey:@"installation_id"]);

    NSDictionary *iosAppState = [actual objectForKey:@"ios_app_state"];
    XCTAssertNotNil(iosAppState);
    XCTAssertEqualObjects(@"ui_application_state_active", [iosAppState objectForKey:@"application_state"]);
    XCTAssertGreaterThan(((NSArray *)[iosAppState objectForKey:@"network_addresses"]).count, 0);
    
    NSArray *titles = [iosAppState objectForKey:@"window_root_view_controller_titles"];
    XCTAssertEqualObjects(@"SiftViewController", [titles objectAtIndex:0]);
    
    NSDictionary *iosDeviceProperties = [actual objectForKey:@"ios_device_properties"];
    XCTAssertNotNil(iosDeviceProperties);
    NSDictionary *entryTypes = @{
        @"bus_frequency": NSNumber.class,
        @"bus_frequency_max": NSNumber.class,
        @"bus_frequency_min": NSNumber.class,
        @"cache_l1_dcache_size": NSNumber.class,
        @"cache_l1_icache_size": NSNumber.class,
        @"cache_l2_cache_size": NSNumber.class,
        @"cache_l3_cache_size": NSNumber.class,
        @"cache_line_size": NSNumber.class,
        @"cpu_64bit_capable": NSNumber.class,
        @"cpu_active_cpu_count": NSNumber.class,
        @"cpu_byte_order": NSString.class,
        @"cpu_count": NSNumber.class,
        @"cpu_family": NSNumber.class,
        @"cpu_frequency": NSNumber.class,
        @"cpu_frequency_max": NSNumber.class,
        @"cpu_frequency_min": NSNumber.class,
        @"cpu_has_fp": NSNumber.class,
        @"cpu_logical_cpu_count": NSNumber.class,
        @"cpu_logical_cpu_max": NSNumber.class,
        @"cpu_physical_cpu_count": NSNumber.class,
        @"cpu_physical_cpu_max": NSNumber.class,
        @"cpu_subtype": NSNumber.class,
        @"cpu_type": NSNumber.class,
        @"device_hardware_machine": NSString.class,
        @"device_hardware_model": NSString.class,
        @"device_host_id": NSNumber.class,
        @"device_host_name": NSString.class,
        @"device_ifa": NSString.class,
        @"device_ifv": NSString.class,
        @"device_kernel_boot_session_uuid": NSString.class,
        @"device_kernel_boot_signature": NSString.class,
        @"device_kernel_uuid": NSString.class,
        @"device_kernel_version": NSString.class,
        @"device_localized_model": NSString.class,
        @"device_memory_size": NSNumber.class,
        @"device_model": NSString.class,
        @"device_name": NSString.class,
        @"device_os_release": NSString.class,
        @"device_os_revision": NSNumber.class,
        @"device_os_type": NSString.class,
        @"device_package_count": NSNumber.class,
        @"device_page_size": NSNumber.class,
        @"device_screen_height": NSNumber.class,
        @"device_screen_width": NSNumber.class,
        @"device_system_name": NSString.class,
        @"device_system_version": NSString.class,
        @"device_tb_frequency": NSNumber.class,
        @"evidence_directories_symlinked": NSArray.class,
        @"evidence_directories_writable": NSArray.class,
        @"evidence_dylds_present": NSArray.class,
        @"evidence_files_present": NSArray.class,
        @"sdk_version": NSString.class,
    };
    
    for (NSString *name in entryTypes) {
        XCTAssert(![iosDeviceProperties objectForKey:name] || [[iosDeviceProperties objectForKey:name] isKindOfClass:[entryTypes objectForKey:name]], @"%@: %@ is not of type %@", name, [iosDeviceProperties objectForKey:name], [entryTypes objectForKey:name]);
    }
    // evidence_url_schemes_openable could be nil.
    XCTAssert(![iosDeviceProperties objectForKey:@"evidence_url_schemes_openable"] ||
              [[iosDeviceProperties objectForKey:@"evidence_url_schemes_openable"] isKindOfClass:NSArray.class]);
}

- (void)testEvent {
    SiftEvent *event = [SiftEvent eventWithType:@"type" path:@"path" fields:@{@"key": @"value"}];
    XCTAssertNotNil(event);

    XCTAssertGreaterThan(event.time, 0);
    XCTAssertEqualObjects(event.type, @"type");
    XCTAssertEqualObjects(event.path, @"path");
    XCTAssertEqualObjects(event.fields, @{@"key": @"value"});
    XCTAssertNil(event.userId);
    XCTAssertNil(event.deviceProperties);
    XCTAssertNil(event.metrics);

    XCTAssertTrue([event isEssentiallyEqualTo:event]);
    XCTAssertFalse([event isEssentiallyEqualTo:nil]);
}

- (void)testCoder {
    SiftEvent *expect = [SiftEvent eventWithType:@"type" path:@"path" fields:@{@"key": @"value"}];
    XCTAssertNotNil(expect);

    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:expect];
    SiftEvent *actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];

    XCTAssertTrue([expect isEssentiallyEqualTo:actual]);
    XCTAssertEqual(actual.time, expect.time);
}

- (void)testListRequest {
    NSArray *events;
    NSDictionary *expect, *actual;

    events = @[];
    expect = @{@"data": @[]};
    actual = [NSJSONSerialization JSONObjectWithData:[SiftEvent listRequest:events] options:0 error:nil];
    XCTAssertEqualObjects(expect, actual);

    events = SFBeNice(@[[SiftEvent eventWithType:@"some-type" path:@"some-path" fields:nil],
                        [SiftEvent eventWithType:nil path:nil fields:@{@"key": @"value"}],
                        [SiftEvent eventWithType:nil path:nil fields:@{@1: @"value"}],  // Key is not string typed.
                        [SiftEvent eventWithType:nil path:nil fields:@{@"key": @1}]]);  // Value is not string typed.
    NSString *ifv = UIDevice.currentDevice.identifierForVendor.UUIDString;
    expect = @{@"data": @[@{@"time": @0, @"mobile_event_type": @"some-type", @"path": @"some-path", @"user_id": @"some-id", @"installation_id": ifv},
                          @{@"time": @0, @"user_id": @"some-id", @"installation_id": ifv, @"fields": @{@"key": @"value"}}]};
    actual = [NSJSONSerialization JSONObjectWithData:[SiftEvent listRequest:events] options:0 error:nil];
    XCTAssertEqualObjects(expect, actual);
}

static NSArray *SFBeNice(NSArray *events) {
    for (SiftEvent *event in events) {
        event.userId = @"some-id";
        event.time = 0;
    }
    return events;
}

@end
