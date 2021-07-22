// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import CoreMotion;
@import Foundation;

#import "SiftHtDictionary.h"
#import "SiftUtils.h"

SiftHtDictionary *SFMakeEmptyIosAppState(void);

SiftHtDictionary *SFCollectIosAppState(CLLocationManager *locationManager, NSString *title) NS_EXTENSION_UNAVAILABLE_IOS("SFCollectIosAppState is not supported for iOS extensions.");

SiftHtDictionary *SFCLHeadingToDictionary(CLHeading *heading);

SiftHtDictionary *SFCLLocationToDictionary(CLLocation *data);

SiftHtDictionary *SFCMDeviceMotionToDictionary(CMDeviceMotion *data, SFTimestamp now);
SiftHtDictionary *SFCMAccelerometerDataToDictionary(CMAccelerometerData *data, SFTimestamp now);
SiftHtDictionary *SFCMGyroDataToDictionary(CMGyroData *data, SFTimestamp now);
SiftHtDictionary *SFCMMagnetometerDataToDictionary(CMMagnetometerData *data, SFTimestamp now);
