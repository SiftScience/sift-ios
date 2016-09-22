// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreLocation;
@import CoreMotion;
@import Foundation;

#import "SFHtDictionary.h"
#import "SFUtils.h"

SFHtDictionary *SFMakeEmptyIosAppState();

SFHtDictionary *SFCollectIosAppState(CLLocationManager *locationManager);

SFHtDictionary *SFCMDeviceMotionToDictionary(CMDeviceMotion *data, SFTimestamp now);
SFHtDictionary *SFCMAccelerometerDataToDictionary(CMAccelerometerData *data, SFTimestamp now);
SFHtDictionary *SFCMGyroDataToDictionary(CMGyroData *data, SFTimestamp now);
SFHtDictionary *SFCMMagnetometerDataToDictionary(CMMagnetometerData *data, SFTimestamp now);
