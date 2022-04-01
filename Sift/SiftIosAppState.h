// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import CoreMotion;
@import Foundation;

#import "SiftUtils.h"

NSMutableDictionary *SFMakeEmptyIosAppState(void);

NSMutableDictionary *SFCollectIosAppState(CLLocationManager *locationManager, NSString *title) NS_EXTENSION_UNAVAILABLE_IOS("SFCollectIosAppState is not supported for iOS extensions.");

NSDictionary *SFCLLocationToDictionary(CLLocation *data);
