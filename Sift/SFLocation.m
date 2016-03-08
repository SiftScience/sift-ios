// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import Foundation;
@import UIKit;

#import "SFDebug.h"

#import "SFLocation.h"

@interface SFAugmentRequest : NSObject

@property SFEvent *event;
@property (nonatomic, copy) OnAugmentCompletion block;

@end

@implementation SFAugmentRequest

@end

//
// Re-update collected data after this amount of seconds.
//
// This is to prevent frequently turning on/off GPS and compass.
//
static const NSTimeInterval SFUpdateAgainAfter = 10;

//
// Wait for GPS and compass data for this amount of seconds.
//
// NOTE: Events will be queued for this much of time, and they are not
// persisted here (unlike SFQueue, which persists events).  So don't set
// this too long.
//
static const NSTimeInterval SFWaitForUpdate = 1;

@implementation SFLocation {
    NSMutableArray<SFAugmentRequest *> *_requests;

    CLLocation *_location;
    CLHeading *_heading;

    CLLocationManager *_manager;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _requests = [NSMutableArray new];

        _location = nil;
        _heading = nil;

        _manager = [CLLocationManager new];
        if (!_manager) {
            self = nil;
            return nil;
        }
        _manager.delegate = self;
    }
    return self;
}

- (void)augment:(SFEvent *)event onCompletion:(OnAugmentCompletion)block {
    SFAugmentRequest *request = [SFAugmentRequest new];
    request.event = event;
    request.block = block;
    @synchronized(self) {
        [_requests addObject:request];
    }
    if ([self isDataFresh]) {
        [self augmentEvents];
    } else {
        [self startUpdates];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, SFWaitForUpdate * NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self augmentEvents];
        });
    }
}

- (void)augmentEvents {
    @synchronized(self) {
        if (!_requests.count) {
            return;
        }

        NSMutableDictionary<NSString *, NSString *> *combined = nil;
        if (_location || _heading) {
            combined = [NSMutableDictionary new];
            if (_location) {
                [combined addEntriesFromDictionary:[self convertLocation:_location]];
            }
            if (_heading) {
                [combined addEntriesFromDictionary:[self convertHeading:_heading]];
            }
        }

        for (SFAugmentRequest *request in _requests) {
            SFEvent *event = request.event;
            if (event.fields && combined) {
                NSMutableDictionary<NSString *, NSString *> *augmented = [NSMutableDictionary dictionaryWithDictionary:combined];
                [augmented addEntriesFromDictionary:event.fields];
                event.fields = augmented;
            } else if (!event.fields) {
                event.fields = combined;
            }
            request.block(request.event);
        }

        [_requests removeAllObjects];
    }
}

- (BOOL)isDataFresh {
    @synchronized(self) {
        if (!_location || -[_location.timestamp timeIntervalSinceNow] > SFUpdateAgainAfter) {
            return NO;
        }
        if ([CLLocationManager headingAvailable]) {
            if (!_heading || -[_heading.timestamp timeIntervalSinceNow] > SFUpdateAgainAfter) {
                return NO;
            }
        }
        return YES;
    }
}

#pragma mark - Location collection

- (void)startUpdates {
    // Start location service _ONLY_ if we've already been granted to do so.
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    if (status != kCLAuthorizationStatusAuthorizedAlways && status != kCLAuthorizationStatusAuthorizedWhenInUse) {
        SF_DEBUG("User did not (yet?) authorize us to use location: status=%d", status);
        return;
    }

    if (status != kCLAuthorizationStatusAuthorizedAlways && UIApplication.sharedApplication.applicationState == UIApplicationStateBackground) {
        SF_DEBUG(@"Not in the foreground");
        return;
    }

    if (![CLLocationManager locationServicesEnabled]) {
        SF_DEBUG("Location service is disabled");
        return;
    }

    @synchronized(self) {
        if (!_location || -[_location.timestamp timeIntervalSinceNow] > SFUpdateAgainAfter) {
            SF_DEBUG(@"Start updating location");
            [_manager requestLocation];
        } else {
            SF_DEBUG(@"Location data is still fresh");
        }

        if ([CLLocationManager headingAvailable]) {
            if (!_heading || -[_heading.timestamp timeIntervalSinceNow] > SFUpdateAgainAfter) {
                SF_DEBUG(@"Start updating heading");
                [_manager startUpdatingHeading];
            } else {
                SF_DEBUG(@"Heading data is still fresh");
            }
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    SF_DEBUG(@"Location udpated");
    CLLocation *location = nil;
    for (CLLocation *loc in locations) {
        if (!location || [loc.timestamp compare:location.timestamp] == NSOrderedDescending) {
            location = loc;
        }
    }
    @synchronized(self) {
        _location = location;
    }
    [_manager stopUpdatingLocation];  // Cancel repeated `requestLocation` if any.
}

- (void)locationManager:(CLLocationManager *)manager didUpdateHeading:(CLHeading *)heading {
    SF_DEBUG(@"Heading udpated");
    @synchronized(self) {
        _heading = heading;
    }
    [_manager stopUpdatingHeading];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    SF_DEBUG(@"Could not update location and/or heading due to %@", [error localizedDescription]);
}

#pragma mark - Conversion

- (NSDictionary<NSString *, NSString *> *)convertLocation:(CLLocation *)location {
    NSMutableDictionary<NSString *, NSString *> *fields = [NSMutableDictionary new];
    fields[@"device_location_time"] = SFDoubleToString([location.timestamp timeIntervalSince1970] * 1000.0);
    if (location.horizontalAccuracy >= 0) {
        fields[@"device_location_lat"] = SFDoubleToString(location.coordinate.latitude);
        fields[@"device_location_lng"] = SFDoubleToString(location.coordinate.longitude);
        fields[@"device_location_horizontal_accuracy"] = SFDoubleToString(location.horizontalAccuracy);
    }
    if (location.verticalAccuracy >= 0) {
        fields[@"device_location_altitude"] = SFDoubleToString(location.altitude);
        fields[@"device_location_vertical_accuracy"] = SFDoubleToString(location.verticalAccuracy);
    }
    if (location.floor) {
        fields[@"device_location_floor"] = [NSNumber numberWithLong:location.floor.level].stringValue;
    }
    if (location.speed >= 0) {
        fields[@"device_location_speed"] = SFDoubleToString(location.speed);
    }
    if (location.course >= 0) {
        fields[@"device_location_course"] = SFDoubleToString(location.course);
    }
    return fields;
}

- (NSDictionary<NSString *, NSString *> *)convertHeading:(CLHeading *)heading {
    NSMutableDictionary<NSString *, NSString *> *fields = [NSMutableDictionary new];
    fields[@"device_heading_time"] = SFDoubleToString([heading.timestamp timeIntervalSince1970] * 1000.0);
    if (heading.headingAccuracy >= 0) {
        fields[@"device_heading_magnetic_heading"] = SFDoubleToString(heading.magneticHeading);
        fields[@"device_heading_heading_accuracy"] = SFDoubleToString(heading.headingAccuracy);
    }
    if (heading.trueHeading >= 0) {
        fields[@"device_heading_true_heading"] = SFDoubleToString(heading.trueHeading);
    }
    fields[@"device_heading_magnetic_field_x"] = SFDoubleToString(heading.x);
    fields[@"device_heading_magnetic_field_y"] = SFDoubleToString(heading.y);
    fields[@"device_heading_magnetic_field_z"] = SFDoubleToString(heading.z);
    return fields;
}

static NSString *SFDoubleToString(double value) {
    return [NSNumber numberWithDouble:value].stringValue;
}

@end
