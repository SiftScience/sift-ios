// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import CoreMotion;
@import Foundation;

#import "SFHtDictionary.h"
#import "SFUtils.h"

SFHtDictionary *SFMakeEmptyIosAppState();

SFHtDictionary *SFCollectIosAppState(CLLocationManager *locationManager);

NSDictionary *SFCMDeviceMotionToDictionary(CMDeviceMotion *data, SFTimestamp now);
NSDictionary *SFCMAccelerometerDataToDictionary(CMAccelerometerData *data, SFTimestamp now);
NSDictionary *SFCMGyroDataToDictionary(CMGyroData *data, SFTimestamp now);
NSDictionary *SFCMMagnetometerDataToDictionary(CMMagnetometerData *data, SFTimestamp now);
