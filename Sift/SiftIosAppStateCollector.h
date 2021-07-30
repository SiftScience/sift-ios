// Copyright (c) 2016 Sift Science. All rights reserved.

@import CoreMotion;
@import Foundation;

/** Collect app states behind the scene. */
@interface SiftIosAppStateCollector : NSObject

- (instancetype)initWithArchivePath:(NSString *)archivePath;

- (void)archive;

/** Collect app state. */
- (void)collectWithTitle:(NSString *)title andTimestamp:(SFTimestamp)now NS_EXTENSION_UNAVAILABLE_IOS("collectWithTitle is not supported for iOS extensions.");

/**
 * Because CMMotionManager is "almost" a global singleton object, we
 * have to coordinate that there is only one CMMotionManager instance
 * that is starting/stopping motion sensors.  If you don't intend to use
 * motion sensors _at all_, you may set this flag to YES, which allows
 * the SDK to use motion sensors.  If you intend to use motion sensors
 * occasionally, please call the following methods to send us motion
 * data.
 */
@property (nonatomic) BOOL allowUsingMotionSensors;

/**
 * If you do intend to use motion sensors, please call these methods to
 * send us motion data you've got.
 */
- (void)updateDeviceMotion:(CMDeviceMotion *)data;
- (void)updateAccelerometerData:(CMAccelerometerData *)data;
- (void)updateGyroData:(CMGyroData *)data;
- (void)updateMagnetometerData:(CMMagnetometerData *)data;

@property (nonatomic) BOOL disallowCollectingLocationData;

@end
