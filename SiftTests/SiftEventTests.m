// Copyright (c) 2016 Sift Science. All rights reserved.

@import XCTest;

@import CoreLocation;
@import UIKit;

#import "SiftIosAppState.h"
#import "SiftIosDeviceProperties.h"
#import "NSData+GZIP.h"

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
    XCTAssertGreaterThan(((NSArray *)[iosAppState objectForKey:@"network_addresses"]).count, 0);
    
    NSArray *titles = [iosAppState objectForKey:@"window_root_view_controller_titles"];
    XCTAssertEqualObjects(@"SiftViewController", [titles objectAtIndex:0]);
    
    NSDictionary *iosDeviceProperties = [actual objectForKey:@"ios_device_properties"];
    XCTAssertNotNil(iosDeviceProperties);
    NSDictionary *entryTypes = @{
        @"device_hardware_machine": NSString.class,
        @"device_ifv": NSString.class,
        @"device_name": NSString.class,
        @"device_system_name": NSString.class,
        @"device_system_version": NSString.class,
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

    NSData *data;
    SiftEvent *actual;
    if (@available(iOS 11.0, macCatalyst 13.0, macOS 10.13, tvOS 11, *)) {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect requiringSecureCoding:NO error:nil];
        NSKeyedUnarchiver* unarchiver = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:nil];
        unarchiver.requiresSecureCoding = NO;
        actual = [unarchiver decodeTopLevelObjectForKey:NSKeyedArchiveRootObjectKey error:nil];
    } else {
        data = [NSKeyedArchiver archivedDataWithRootObject:expect];
        actual = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    }
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

- (void)testSanityCheck {
    SiftEvent *event1 = [SiftEvent eventWithType:@"type" path:@"path" fields:@{@"key": @"value"}];
    XCTAssertNotNil(event1);
    XCTAssertTrue([event1 sanityCheck]);
    
    SiftEvent *event2 = [SiftEvent eventWithType:@"type" path:@"path" fields:@{@"key": @5436}];
    XCTAssertNotNil(event2);
    XCTAssertFalse([event2 sanityCheck]);
}

- (void)testGZippedData {
    NSArray *events = @[];
    events = SFBeNice(@[[SiftEvent eventWithType:@"some-type" path:@"some-path" fields:nil],
                        [SiftEvent eventWithType:nil path:nil fields:@{@"key": @"value"}]]);
    NSData *body = [[SiftEvent listRequest:events] gzippedData];
    XCTAssertTrue(body.isGzippedData);
}

- (void)testUnGZippedData {
    NSArray *events = @[];
    events = SFBeNice(@[[SiftEvent eventWithType:@"some-type" path:@"some-path" fields:nil],
                        [SiftEvent eventWithType:nil path:nil fields:@{@"key": @"value"}]]);
    
    NSData *unzipBody1 = [[SiftEvent listRequest:events]  gunzippedData];
    XCTAssertFalse(unzipBody1.isGzippedData);

    NSData *body = [[SiftEvent listRequest:events] gzippedData];
    XCTAssertTrue(body.isGzippedData);
    NSData *unzipBody2 = [body gunzippedData];
    XCTAssertFalse(unzipBody2.isGzippedData);
}

@end
