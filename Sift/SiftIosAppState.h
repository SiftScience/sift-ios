// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import CoreMotion;
@import Foundation;

#import "SiftUtils.h"

NSMutableDictionary *SFMakeEmptyIosAppState(void);

NS_EXTENSION_UNAVAILABLE_IOS("SFCollectIosAppState is not supported for iOS extensions.")
NSMutableDictionary *SFCollectIosAppState(CLLocationManager *locationManager, NSString *title);

NSDictionary *SFCLHeadingToDictionary(CLHeading *heading);

NSDictionary *SFCLLocationToDictionary(CLLocation *data);

NSDictionary *SFCMDeviceMotionToDictionary(CMDeviceMotion *data, SFTimestamp now);
NSDictionary *SFCMAccelerometerDataToDictionary(CMAccelerometerData *data, SFTimestamp now);
NSDictionary *SFCMGyroDataToDictionary(CMGyroData *data, SFTimestamp now);
NSDictionary *SFCMMagnetometerDataToDictionary(CMMagnetometerData *data, SFTimestamp now);
