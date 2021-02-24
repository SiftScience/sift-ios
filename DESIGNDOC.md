# **Sift iOS SDK**

### Mobile IOS SDK Software Design Documentation

##
### Table of Contents

**[1 Overview](#1-overview)**

**[2 High Level Class Diagram](#2-high-level-class-diagram)**

**[3 Data Models](#3-data-models)**
* [3.1 SiftEvent](#31-siftEvent)
* [3.2 DeviceProperties](#32-iosDeviceProperties)
* [3.3 AppState](#33-iosAppState)
* [3.4 Location](#34-location)
* [3.5 Heading](#35-heading)
* [3.6 DeviceMotion](#36-deviceMotion)
* [3.7 DeviceAccelerometerData](#37-deviceAccelerometerData)
* [3.8 DeviceGyroData](#38-deviceGyroData)
* [3.9 DeviceMagnetometerData](#39-deviceMagnetometerData)

**[4 Modules](#4-modules)**

* [4.1 SIFT](#41-sift)
* [4.2 SIFT EVENT](#42-siftEvent)
* [4.3 SIFT QUEUE](#43-siftQueue) 
* [4.4 SIFT UPLOADER ](#43-siftUploader) 

**[5 Flow Chart](#5-flow-chart)**

##


## 1 Overview

The [sift-ios](https://github.com/SiftScience/sift-ios)  Mobile SDKs collect and send device information and app life cycle events to Sift. Objective C will be used as the programming language and Xcode will be used as the IDE.  SDK will be supporting ios 9.2 as deployment target.

The specific features used are: CoreMotion, BatteryManager, Location, NetworkInterface and TelephonyManager. The SDK uses CoreMotion, BatteryManager, Location and NetworkInterface for collecting AppState details. The Device properties details are collected with the help of TelephonyManager and PackageManager along with Build details. In particular, event collecting, appending and uploading are handled on a separate thread with the help of Executors. The Mobile SDKs allow mobile applications to collect and send device properties and application lifecycle events to Sift. 

A high-level block diagram is shown
**![](https://docs.google.com/drawings/u/0/d/sqNOp2NE6OcWUAASs69Kfyw/image?w=585&h=247&rev=1&ac=1&parent=1AslLsJQep2FgRO7_E3xe1jXwTkwIEWJ1_Ris7i3MTUI)**

1. IOS app loads the SDK with the Sift configurations.
2. The sift SDK will collect and send events to the Sift server when there are events to upload.

This document describes the data models,classes for handling events, and specific flows, respectively.


## 2 High Level Class Diagram

**![{"theme":"neutral","source":"classDiagram\n      SiftEvent <|-- AppStateCollector\n      SiftEvent <|-- DevicePropertiesCollector\n      \n\nclass SiftEvent {\n          +NSString time\n          +NSString type\n          +NSString path\n          +NSString userId\n          +NSString installationId\n          +NSString fields\n          +NSNumber deviceProperties\n          +AppStateCollector iosAppState          \n          +DevicePropertiesCollector iosDeviceProperties   \n          +NSString metrics\n      }\n\n      class AppStateCollector {\n          +NSString application_state\n          +NSString sdk_version\n          +NSArray window_root_view_controller_titles\n          +NSNumber battery_level\n          +NSString battery_state\n          +NSString device_orientation\n          +NSNumber proximity_state\n          +NSDictionary location          \n          +NSDictionary heading   \n          +NSArray motion\n          +NSArray raw_accelerometer\n          +NSArray raw_gyro\n          +NSArray raw_magnetometer\n      }\n\n      class DevicePropertiesCollector {\n          +NSString app_name\n          +NSString app_version\n          +NSString sdk_version\n          +NSString device_name\n          +NSString device_model\n          +NSString device_ifa\n          +NSString device_ifv\n          +NSNumber device_screen_width\n          +NSNumber device_screen_height\n          +NSString device_localized_model\n          +NSString device_system_name\n          +NSString device_system_version\n          +NSString mobile_carrier_name\n          +NSString mobile_iso_country_code\n          +NSString mobile_country_code\n          +NSString mobile_network_code\n          +NSNumber is_simulator\n      }"}](https://lh4.googleusercontent.com/fl_1hqrZei_tEIb5zZY6DKzfL8uoZyZjN1PVnQjQX-Dg4Ub4OCvLNYRAMA-tKn2YvsVe9ieSC7LW9ydnTnpHM8L-mTsYsxWvskBEbNH_ONmCSXlhP_wU7ynJ1N5B65hdm6UU_8Zi "mermaid-graph")**


Class Diagram for App State Collector shown below:

**![{"theme":"neutral","source":"classDiagram\n      AppStateCollector <|-- Location\n      AppStateCollector <|-- Heading\n      AppStateCollector <|-- DeviceMotion\n      DeviceMotion <|-- DeviceAccelerometerData\n      DeviceMotion <|-- DeviceGyroData\n      DeviceMotion <|-- DeviceMagnetometerData\n      \n      class AppStateCollector {\n          +NSString application_state\n          +NSString sdk_version\n          +NSArray window_root_view_controller_titles\n          +NSNumber battery_level\n          +NSString battery_state\n          +NSString device_orientation\n          +NSNumber proximity_state\n          +Location location          \n          +Heading heading   \n          +NSArray motion\n          +NSArray raw_accelerometer\n          +NSArray raw_gyro\n          +NSArray raw_magnetometer\n  \n      }\n\n      class Location {\n          +NSNumber latitude\n          +NSNumber longitude\n          +NSNumber altitude\n          +NSNumber horizontal_accuracy\n          +NSNumber vertical_accuracy\n          +NSNumber floor\n          +NSNumber speed\n          +NSNumber course\n      }\n\n     class Heading {\n          +NSNumber time\n          +NSNumber magnetic_heading\n          +NSNumber accuracy\n          +NSNumber true_heading\n          +NSNumber raw_magnetic_field_x\n          +NSNumber raw_magnetic_field_y\n          +NSNumber raw_magnetic_field_z\n      }\n\n      class DeviceMotion {\n          +NSNumber time\n          +NSNumber attitude_roll\n          +NSNumber attitude_pitch\n          +NSNumber attitude_yaw\n          +NSNumber rotation_rate_x\n          +NSNumber rotation_rate_y\n          +NSNumber rotation_rate_z\n          +NSNumber gravity_x\n          +NSNumber gravity_y\n          +NSNumber gravity_z\n          +NSNumber user_acceleration_x\n          +NSNumber user_acceleration_y\n          +NSNumber user_acceleration_z\n          +NSNumber magnetic_field_x\n          +NSNumber magnetic_field_y\n          +NSNumber magnetic_field_z\n          +NSString magnetic_field_calibration_accuracy\n      }\n\n      class DeviceAccelerometerData {\n          +NSNumber time\n          +NSNumber acceleration_x\n          +NSNumber acceleration_y\n          +NSNumber acceleration_z\n      }\n\n      class DeviceGyroData {\n          +NSNumber time\n          +NSNumber rotation_rate_x\n          +NSNumber rotation_rate_y\n          +NSNumber rotation_rate_z\n      }\n\n      class DeviceMagnetometerData {\n          +NSNumber time\n          +NSNumber magnetic_field_x\n          +NSNumber magnetic_field_y\n          +NSNumber magnetic_field_z\n      }"}](https://lh6.googleusercontent.com/MJ_A59ZMCIMWFgeTYWdRN8TXXvTf88p_CwzZSUDVCYLkRKBZsiQUNsSZqu68JdhiECAHyn9yJT9pPBOjZbqOt3uR-km4tjX2st15xrF1yfWEqj1t_wT1gY--onICKu-muzaLNzN7 "mermaid-graph")**



## 3 Data Models

The data models is to understand the responsibility (attributes and methods) of each class that should be clearly identified.

### 3.1 SiftEvent

The SiftEvent mainly collects the following information:

- **time** : {type: int64_t}
  - It indicates the time (in ms since the unix epoch) that this event occurred. Default value is now.
- **type** : {type: string}
  - It indicates the mobile event type. Default value is nil.
- **path** : {type: string}
  - It indicates the event path. Default value is nil.
- **userId** : {type: string}
  - It indicates the user ID. If not set, the event queue will use the user ID set in the shared Sift object.
- **installationId** : {type: string}
  - The installation id indicates the 64-bit number (expressed as a hexadecimal string) unique ID to each device.
- **fields** : {type: string}
  - It indicates custom event fields; both key and value must be string typed. Default value is nil.
- **iosDeviceProperties** : {type: DevicePropertiesCollector}
  - The ios device property indicates the device related properties as mentioned in [section 3.2](#32-iosDeviceProperties)
- **iosAppState** : {type: AppStateCollector}
  - The ios app state indicates the application related datas as mentioned in [section 3.3](#33-iosAppState).
- **metrics** : {type: string}
  - It indicates the internal metrics. Default value is nil.

Class diagram of SiftEvent:
**![{"theme":"neutral","source":"classDiagram\nclass SiftEvent {\n          +int64_t time\n          +NSString type\n          +NSString path\n          +NSString userId\n          +NSString installationId\n          +NSString fields\n          +NSNumber deviceProperties\n          +AppStateCollector iosAppState          \n          +DevicePropertiesCollector iosDeviceProperties   \n          +NSString metrics\n          +eventWithType(type, path, fields) SiftEvent\n          +isEssentiallyEqualTo(event) BOOL\n          +sanityCheck() BOOL\n          +listRequest(events) NSData\n      }"}](https://lh5.googleusercontent.com/zKeIKOoe3QM8mVAk3nOnDYYBksNo_e2PtpgRi8Mp8ElxKVBVpkTO0iJucRJb-GFvGMuGTVeAsNCDwHxzkKx2AAztmrgJ_NmtZ4d-g1ovgrBFHjiYRIX_jHiKhscDEE3UXHsWcj8C "mermaid-graph")**

###

### 3.2 DeviceProperties

The iOSDeviceProperties collects the following information:

- **app_name** : {type: string}
  - The app name indicates the name of the application in which the sift SDK is used.
- **app_version** : {type: string}
  - The app version indicates the current version name of the application in which the sift SDK is used.
- **sdk_version** : {type: string}
  - The sdk version indicates the current version of the sift SDK that has been used in the application.
- **device_name** : {type: string}
  - It indicates device  name.
- **device_model** : {type: string}
    - The device model indicates the end-user-visible model name for the end product.
- **device_ifa** : {type: string}
    - Identifier for Advertisers (IFA or IDFA) is a temporary device identifier used by the Apple set of handheld devices. A successor of Unique Device Identifier (UDID), IFA is available on all devices with versions iOS 6 and later..
- **device_ifv** : {type: string}
    - The identifierForVendor is an alphanumeric string that uniquely identifies a device to the app’s vendor..
- **device_screen_width** : {type: integer}
    - It indicates the device screen width.
- **device_screen_height** : {type: integer}
   - It indicates the device screen height.
- **device_localized_model** : {type: string}
    - It indicates the localized version of model.
- **device_system_name** : {type: string}
  - It indicates the user-visible operating system name string.  Eg: iOS
- **device_system_version** : {type: string}
  - It indicates the user-visible operating system version string. Eg: 13.3
- **mobile_carrier_name** : {type: string}
    - The mobile carrier name indicates the alphabetic name of the current registered network operator.
- **mobile_iso_country_code** : {type: string}
  - It indicates the ISO country code for the user’s cellular service provider..
- **mobile_network_code** : {type: string}
  - It indicates the mobile network code for the user’s cellular service provider.
- **is_simulator** : {type: integer}
  - It indicates if device is simulator or not.

Class diagram of iOSDeviceProperties:
**![{"theme":"neutral","source":"classDiagram\n class DevicePropertiesCollector {\n          +NSString app_name\n          +NSString app_version\n          +NSString sdk_version\n          +NSString device_name\n          +NSString device_model\n          +NSString device_ifa\n          +NSString device_ifv\n          +NSNumber device_screen_width\n          +NSNumber device_screen_height\n          +NSString device_localized_model\n          +NSString device_system_name\n          +NSString device_system_version\n          +NSString mobile_carrier_name\n          +NSString mobile_iso_country_code\n          +NSString mobile_country_code\n          +NSString mobile_network_code\n          +NSNumber is_simulator\n          +collect()\n      }"}](https://lh3.googleusercontent.com/_chFEudlSQWlDQFTAglbQEf16Gl0CJQ3s5G5hpzpvFIXvxcEbSuCKHlMA97FneoFQmoSDs5iO1QiVdwrH3EPY7VKt09WyZGRL3eU_fT8ErZXAh1wKqjwfR1v9k2Il-y6UOUgPZWQ "mermaid-graph")**


###

### 3.3 AppState

The iOSAppState collects the following informations:

- **application_state** : {type: string}
  - Constants that indicate the running states of an app. 
    - UIApplicationStateActive -> The app is running in the foreground and currently receiving events.
    - UIApplicationStateInactive -> The app is running in the foreground but is not receiving events.
    - UIApplicationStateBackground -> The app is running in the background.
- **sdk_version** : {type: string}
  - The sdk version indicates the current Sift SDK version which is used.
- **window_root_view_controller_titles** : {type: array}
  - The window root class name indicates the current view controller class name from where the data are collected.
- **battery_level** : {type: number}
  - The current battery level, from 0 to 1.0 and -1.0 if UIDeviceBatteryStateUnknown.
- **battery_state** : {type: string}
  - It indicates the current state of battery. There are following 4 cases:
    - UIDeviceBatteryStateUnknown -> if monitoring disabled.
    - UIDeviceBatteryStateUnplugged -> on battery, discharging
    - UIDeviceBatteryStateCharging -> plugged in, less than 100%
    - UIDeviceBatteryStateFull -> plugged in, at 100%
- **device_orientation** : {type: string}
  - Constants that describe the physical orientation of the device.
    - UIDeviceOrientationUnknown -> The orientation of the device cannot be determined.
    - UIDeviceOrientationPortrait -> The device is in portrait mode, with the device held upright and the Home button at the bottom.
    - UIDeviceOrientationPortraitUpsideDown -> The device is in portrait mode but upside down, with the device held upright and the Home button at the top.
    - UIDeviceOrientationLandscapeLeft -> The device is in landscape mode, with the device held upright and the Home button on the right side.
    - UIDeviceOrientationLandscapeRight -> The device is in landscape mode, with the device held upright and the Home button on the left side.
    - UIDeviceOrientationFaceUp -> The device is held parallel to the ground with the screen facing upwards.
    - UIDeviceOrientationFaceDown -> The device is held parallel to the ground with the screen facing downwards.
- **proximity_state** : {type: number}
   - A Boolean value that indicates whether the proximity sensor is close to the user.
- **location** : {type: dictionary}
  - The location consists of collective information of latitude, longitude, accuracy and the time at which data was collected as shown in the [section 3.4](#34-location). (_Have data only if the sift configuration and permissions are enabled_)
- **heading** : {type: dictionary}
  - The heading consists of collective information of time, magnetic heading, accuracy, true heading and raw magnetic field values was collected as shown in the [section 3.5](#35-heading).
- **network_addresses** : {type: array}
  - The network addresses indicate the list of IP addresses of the current device in which the SDK is running. 
- **motion** : {type: array}
  - Encapsulated measurements of the attitude, rotation rate, and acceleration of a device was collected as shown in the [section 3.6](#36-deviceMotion).
- **raw_accelerometer** : {type: array}
  - Retrieve data from the onboard accelerometers of a device was collected as shown in the [section 3.7](#37-deviceAccelerometerData).
- **raw_gyro** : {type: array}
  - Retrieve data from the onboard gyroscopes value of a device was collected as shown in the [section 3.8](#38-deviceGyroData).
- **raw_magnetometer** : {type: array}
  - Measurements of the Earth's magnetic field relative to the device was collected as shown in the [section 3.9](#39-deviceMagnetometerData).

Class diagram of iOSAppState:
**![{"theme":"neutral","source":"classDiagram\nclass AppStateCollector {\n          +NSString application_state\n          +NSString sdk_version\n          +NSArray window_root_view_controller_titles\n          +NSNumber battery_level\n          +NSString battery_state\n          +NSString device_orientation\n          +NSNumber proximity_state\n          +NSDictionary location          \n          +NSDictionary heading  \n          +NSArray network_addresses \n          +NSArray motion\n          +NSArray raw_accelerometer\n          +NSArray raw_gyro\n          +NSArray raw_magnetometer\n      }"}](https://lh3.googleusercontent.com/HP-2njcgFl2GlZqJcRQGNlNsZR_BKyAusmMpUWxNnd53rv74fxHTqEhmKHJbL-jtNdiHRw50cp6WVp7MYSob5ysL2vAD_lDQTeycxicF_cVp60Bv2NWswVPzsGKw0m7oTa5fYFNu "mermaid-graph")**

###

### 3.4 Location

The location consist of the following information:

- **time** : {type: number}
  - It indicates the time at which the location data was collected.
- **latitude** : {type: number}
  - Which indicates the latitude of the collected location.
- **longitude** : {type: number}
  - Which indicates the longitude of the collected location.
- **altitude** : {type: number}
  - Which indicates the altitude, measured in meters.
- **horizontal_accuracy** : {type: number}
  - Indicates the radius of uncertainty for the location, measured in meters.
- **vertical_accuracy** : {type: number}
  - Indicates the accuracy of the altitude value, measured in meters.
- **floor** : {type: number}
  - Indicates the logical floor of the building in which the user is located..
- **speed** : {type: number}
  - Indicates the accuracy of the speed value, measured in meters per second.
- **course** : {type: number}
  - Indicates the accuracy of the course value, measured in degrees.

Class diagram for Location:
**![{"theme":"neutral","source":"classDiagram\nclass Location {\n          +NSNumber latitude\n          +NSNumber longitude\n          +NSNumber altitude\n          +NSNumber horizontal_accuracy\n          +NSNumber vertical_accuracy\n          +NSNumber floor\n          +NSNumber speed\n          +NSNumber course\n          +disallowCollectingLocationData() BOOL\n          +setDisallowCollectingLocationData:(BOOL)\n          +canCollectLocationData() BOOL\n      }"}](https://lh4.googleusercontent.com/Tz-Vh5_oYbtLY_EkxUQcrtuRC1rrBuJV9pzbw4CR8n6eTcET6YUhxAq7ROfflDYLQdyh9_FqefTb3YzHEIxdmNx6TvYs9wDI7wdBV8ZeMOAEMJRRS6fEER837RVCEx9Pu-5KNP0I "mermaid-graph")**

###

### 3.5 Heading

The azimuth (orientation) of the user’s device, relative to true or magnetic north. The heading mainly collects the following information:

- **time** : {type: number}
  - It indicates the time at which this heading was determined.
- **magnetic_heading** : {type: number}
  - It indicates the heading (measured in degrees) relative to magnetic north.
- **accuracy** : {type: number}
  - It indicates the maximum deviation (measured in degrees) between the reported heading and the true geomagnetic heading.
- **true_heading** : {type: number}
  - The heading (measured in degrees) relative to true north.
- **raw_magnetic_field_x** : {type: number}
  - The geomagnetic data (measured in microteslas) for the x-axis.
- **raw_magnetic_field_y** : {type: number}
  - The geomagnetic data (measured in microteslas) for the y-axis.
- **raw_magnetic_field_z** : {type: number}
  - The geomagnetic data (measured in microteslas) for the z-axis

Class diagram of Heading:
**![{"theme":"neutral","source":"classDiagram\n class Heading {\n          +NSNumber time\n          +NSNumber magnetic_heading\n          +NSNumber accuracy\n          +NSNumber true_heading\n          +NSNumber raw_magnetic_field_x\n          +NSNumber raw_magnetic_field_y\n          +NSNumber raw_magnetic_field_z\n      }"}](https://lh4.googleusercontent.com/7LoVILiiKQosYCa3iigjFRiODKpcRr0AW-cyAQheFcf9irVs7wgR2Gvu8FupP0TtG3sHt-4YqOm6jWLG9VeB1qKw69XizOLfYUBxHTXlzkgH_UWPeprOHEd5ZqhgkcGtgqhI7VNd "mermaid-graph")**

###

### 3.6 DeviceMotion

The iosDeviceMotion mainly collects the following information:

- **time** : {type: number}
  - It indicates the time at which this motion was determined.
- **attitude_roll** : {type: double}
  - A roll is a rotation around a longitudinal axis that passes through the device from its top to bottom. The roll of the device, in radians.
- **attitude_pitch** : {type: double}
  - A pitch is a rotation around a lateral axis that passes through the device from side to side. The pitch of the device, in radians.
- **attitude_yaw** : {type: double}
  - A yaw is a rotation around an axis that runs vertically through the device. The yaw of the device, in radians.
- **rotation_rate_x** : {type: number}
  - The rotation rate of the device for the x-axis.
- **rotation_rate_y** : {type: number}
  - The rotation rate of the device for the y-axis.
- **rotation_rate_z** : {type: number}
  - The rotation rate of the device for the z-axis.
- **gravity_x** : {type: number}
  - The gravity acceleration vector expressed in the device's reference frame for the x-axis.
- **gravity_y** : {type: number}
  - The gravity acceleration vector expressed in the device's reference frame for the y-axis.
- **gravity_z** : {type: number}
  - The gravity acceleration vector expressed in the device's reference frame for the z-axis.
- **user_acceleration_x** : {type: number}
  - The acceleration that the user is giving to the device for the x-axis.
- **user_acceleration_y** : {type: number}
  - The acceleration that the user is giving to the device for the y-axis.
- **user_acceleration_z** : {type: number}
  - The acceleration that the user is giving to the device for the z-axis.
- **magnetic_field_x** : {type: number}
  - Returns the magnetic field vector with respect to the device for the x-axis.
- **magnetic_field_y** : {type: number}
  - Returns the magnetic field vector with respect to the device for the y-axis.
- **magnetic_field_z** : {type: number}
  - Returns the magnetic field vector with respect to the device for the z-axis.
- **magnetic_field_calibration_accuracy** : {type: string}
  - It Indicates the calibration accuracy of a magnetic field estimate.

Class diagram of DeviceMotion:
**![{"theme":"neutral","source":"classDiagram\nclass DeviceMotion {\n          +NSNumber time\n          +NSNumber attitude_roll\n          +NSNumber attitude_pitch\n          +NSNumber attitude_yaw\n          +NSNumber rotation_rate_x\n          +NSNumber rotation_rate_y\n          +NSNumber rotation_rate_z\n          +NSNumber gravity_x\n          +NSNumber gravity_y\n          +NSNumber gravity_z\n          +NSNumber user_acceleration_x\n          +NSNumber user_acceleration_y\n          +NSNumber user_acceleration_z\n          +NSNumber magnetic_field_x\n          +NSNumber magnetic_field_y\n          +NSNumber magnetic_field_z\n          +NSString magnetic_field_calibration_accuracy\n          +allowUsingMotionSensors() BOOL\n          \n          +setAllowUsingMotionSensors:(allowUsingMotionSensors)\n          +updateDeviceMotion:(data)\n          +startMotionSensors()\n          +stopMotionSensors()\n      }"}](https://lh4.googleusercontent.com/tB9F_E845f2d3nQyCummYPRMzOgYuq2e5N1votD4iHCDAikK-yoleMG4ObB1huFRo4oiir6WdkETFXrD6Jw6K8IBUNJhK1rp0dLk-JL0B9tHkCf9yvAUBCrkNhqpBFJVsSEX16-z "mermaid-graph")**

###

### 3.7 DeviceAccelerometerData

The accelerometer data mainly collects the following information:

- **time** : {type: number}
  - It indicates the time at which this motion was determined.
- **acceleration_x** : {type: number}
  - The acceleration that the user is giving to the device for the x-axis.
- **acceleration_y** : {type: number}
  - The acceleration that the user is giving to the device for the y-axis.
- **acceleration_z** : {type: number}
  - The acceleration that the user is giving to the device for the z-axis.

Class diagram of DeviceAccelerometerData:
**![{"theme":"neutral","source":"classDiagram\nclass DeviceAccelerometerData {\n          +NSNumber time\n          +NSNumber acceleration_x\n          +NSNumber acceleration_y\n          +NSNumber acceleration_z\n          +updateAccelerometerData:(data)\n      }"}](https://lh6.googleusercontent.com/xPqBJAZ1Eeno4xpmRU8HO2zmv7jTZgjY-HIvGfwhPnnZLV13J-0mr1a8AOaIvZ8e5lzkIU11G9nmX3LLSTFqbvBazkYKNmwaJqC728JnT1ztr_JKlz4zGoQFm04sE4zyFpKenAcp "mermaid-graph")**

###

### 3.8 DeviceGyroData

The gyro data mainly collects the following information:

- **time** : {type: number}
  - It indicates the time at which this motion was determined.
- **rotation_rate_x** : {type: number}
  - The rotation rate of the device for the x-axis.
- **rotation_rate_y** : {type: number}
  - The rotation rate of the device for the y-axis.
- **rotation_rate_z** : {type: number}
  - The rotation rate of the device for the z-axis.

Class diagram of DeviceGyroData:
**![{"theme":"neutral","source":"classDiagram\nclass DeviceGyroData {\n          +NSNumber time\n          +NSNumber rotation_rate_x\n          +NSNumber rotation_rate_y\n          +NSNumber rotation_rate_z\n\t  +updateGyroData:(data)\n      }"}](https://lh4.googleusercontent.com/_jacwvk5ktMxpcFtN2uMyUVx2q4rinukv6ItB21DPx69J83Y67PrMzroN6vwQnfa00j2ZmJK1fYjF4ITOYoHOZlYO58O78WDgHGuty610M0SVtu2-I2HxTixzNO_TyjLEZyPKRo6 "mermaid-graph")**

###

### 3.9 DeviceMagnetometerData

The magnetometer data mainly collects the following information:

- **time** : {type: number}
  - It indicates the time at which this motion was determined.
- **magnetic_field_x** : {type: number}
  - Returns the magnetic field vector with respect to the device for the x-axis.
- **magnetic_field_y** : {type: number}
  - Returns the magnetic field vector with respect to the device for the y-axis.
- **magnetic_field_z** : {type: number}
  - Returns the magnetic field vector with respect to the device for the z-axis.

Class diagram of DeviceMagnetometerData:
**![{"theme":"neutral","source":"classDiagram\nclass DeviceMagnetometerData {\n          +NSNumber time\n          +NSNumber magnetic_field_x\n          +NSNumber magnetic_field_y\n          +NSNumber magnetic_field_z\n\t  +updateMagnetometerData:(data)\n      }"}](https://lh4.googleusercontent.com/HIVt3ws3XizhGi3RDtOOUeECc1hDVBKrwizye2Fcr5DjOsRYEiQnNUrbN-Q2wXTCyV8bkoLSffTLJTzrZ4NVOrjlqnqNlgFJpA3G8qKXZNHR_cmTItzXNH3iGH2yzjkrTQO2oZ6w "mermaid-graph")**


## 4 Modules

The SDK also has a number of classes that deal with event collecting, saving and uploading to Sift server.

### 4.1 Sift

This is a utility class of the sift client library which handles the application-level code for interacting with the framework for collecting, saving and uploading events. This class sets up and holds references to the event queues and event collectors, including AppStateCollector and DevicePropertiesCollector.

Configuring of the Sift iOS SDK requires passing in your account id and beacon key.
```Objective C
Sift *sift = [Sift sharedInstance];

// At minimum, you should configure these two
[sift setAccountId:@"YOUR_ACCOUNT_ID"];
[sift setBeaconKey:@"YOUR_JAVASCRIPT_SNIPPET_KEY"];
```

```Swift
let sift = Sift.sharedInstance
sift().accountId = "YOUR_ACCOUNT_ID"
sift().beaconKey = "YOUR_JAVASCRIPT_SNIPPET_KEY"
```

Sift class provide a builder class to initialize the configuration data and variable to set value:
- **(instancetype)sharedInstance**
  - It return the shared instance of Sift to initialise the RootDirPath value:
- **initWithRootDirPath**(_rootDirPath_)
  - **_rootDirPath_** : {type: string}
    - Set rootDirPath value and serverUrlFormat value that is the location of the API endpoint; defaults to @"https://api3.siftscience.com/v3/accounts/%@/mobile_events"
- **accountId** : {type: string}
- Your account ID; defaults to nil.
- **beaconKey** : {type: string}
- Your beacon key; defaults to nil.
- **userId** : {type: string}
- Your User ID; defaults to nil.
- **disallowCollectingLocationData** : {type: boolean}
- Whether to allow location collection; defaults to false.

This class mainly handles the following task:

- Archive/Save all of the sift instance states to the disk using shared preference, which includes Sift.Config, user Id, app state queue and device properties queue.
- Unarchive/Restore all the sift instance states(Sift.Confi, user Id, and queues) from disk.
- Appends the collected event to the App State queue and Device Properties queue.
- Setting Sift.Config.
- Setting user Id.

Following are the static API to interact with SDK:
- **setAccountId**(_accountId_)
    - It will set the accountId inside the sift instance.
- **setBeaconKey**(_beaconKey_)
    - It will set the beaconKey inside the sift instance..
- **setUserId**(_userId_)
  - It will set the userId inside the sift instance.
- **unsetUserId**()
  - Which removes any current useId to nil
- **setDisallowCollectingLocationData**(_disallowCollectingLocationData_)
  - Whether to allow location collection; defaults to false.
- **upload**()
  - It will call the upload method with force param as NO.
- **upload**(_force_)
  - It will upload the collects events to Sift Server. If force is YES, then won't wait for queue.readyForUpload to be true.


  - Should call in the onCreate() callback of each Activity.
  - It creates the Sift singleton instance and collectors if they do not exist, and passes along the current Activity context.
  - For your application&#39;s main Activity, make sure to provide a Sift.Config object as the second parameter.
  - If you are integrating per-Activity rather than at the Application level, you can specify the name that will be associated with each Activity event (defaults to the class name of the embedding Activity).
  - There are overloaded methods below for your convenience.
    - open(context, activityName)
    - open(context, config)
    - open(context)
- **collect**()
  - Should call Sift.collect() after the Sift.open() call in each Activity.
  - Which executes a runnable task to collect SDK events for Device Properties and Application State.
- **pause**()
  - Should call Sift.pause() in the onPause() callback of each Activity.
  - Which persists the instance state to disk and disconnects location services.
- **resume**(_context, activityName_)
  - Should call Sift.resume() in the onResume() callback of each Activity.
  - It will try to reconnect the location services if configuration and permissions are enabled.
  - If you provide a non-null activity name as a parameter then it will set the current activity class name as the name provided, otherwise it will set the simple name of the underlying class.
  - There is an overloaded method for your convenience.
    - resume(context)
- **close**()
  - Call Sift.close() in the onDestroy() callback of each Activity.
  - It persists the instance state to disk and disconnects location services.

- **archiveKeys**()

### 4.2 SiftEvent
It provides the implementation of interfaces like _UserIdProvider_ and _UploadRequester_ in Queue and _ConfigProvider_ in Uploader.
These tasks runon a separate executor, so that if any largeamounts of data does not affect the main thread.
To execute those task it provide the following instance API:

This class is the implementation of manage Sift Events that collected from app state collector and device properties collector. 
SiftEvent mainly handles the following task:
- Collect the events in proper format in dictionary and do the sanity check. So that it will easier to encode and decode the events.
- Appends the collected event to the list request.

This class have the following methods:

- **eventWithType**(_type_, _path_, _fields_)
  - It will the create the event with specified type.
- **isEssentiallyEqualTo**(_event_)
  - It compare event contents except time. Its return boolean value.
- **listRequest**(_events_)
  - Create a JSON-encoded list request object. It return as NSData.
- **appendDevicePropertiesEvent**(_event_)
  - Which invokes the task manager to execute the append task with Device Properties queue identifier and provided event.
- **sanityCheck**()
  - it return YES if event contents make sense.

### 4.3 SiftQueue

This class is for holding events until they are ready for upload to the sift server. Whenever an event is collected and tries to add either in the App State or Device Properties queue, it will append and upload depending on the queue's batching policy. The queue's batching policy is controlled by the queue configuration and state of the queue.

The queue configuration depends on the following factors:

- **acceptSameEventAfter** : {type: long}
  - Time after which an event that is basically the same as the most recently appended event can be appended again.
- **uploadWhenMoreThan** : {type: int}
  - Max queue depth before flush and upload request.
- **uploadWhenOlderThan** : {type: long}
  - Max queue age before flush and upload request.

Which can be initialized through the queue config class, which provide the following methods:

- withAcceptSameEventAfter(_acceptSameEventAfter_): {type: long}
- withUploadWhenMoreThan(_uploadWhenMoreThan_): {type: int}
- withUploadWhenOlderThan(_uploadWhenOlderThan_): {type: long}

```Objective C
 static const SiftQueueConfig SFIosDevicePropertiesCollectorQueueConfig = {
     .uploadWhenMoreThan = 0,
     .acceptSameEventAfter = 3600  // 1 hour
 };
```
The DeviceProperties queue is configured as:

- _acceptSameEventAfter: **3600**_ // 1 hour
- _uploadWhenMoreThan: **0**_

The AppState queue is configured as:

- _uploadWhenMoreThan: **32**_ // Unit: number of events.
- _uploadWhenOlderThan: **60**_  // 1 minute.

This class holds the state of the queue with the following attributes:

- **identifier** : {type: string}
  - The identifier is the key for the queue.
- **queue** : {type: NSMutableArray}
  - The list of collected events as of now to be uploaded depending on the policy.
- **config** : {type: SiftQueueConfig}
  - The configuration of the queue which decides the batching policy.
- **lastEvent** : {type: SiftEvent}
  - The recent event added to the queue.
- **lastUploadTimestamp:** {type: SFTimestamp}
  - The time at which recent upload was carried on.
- **archivePath:** {type: string}
  - The time at which recent upload was carried on.

This class have the following methods:

- **archive**()
  - This method write the queue content to specified path in NSMutableDictionary format. This dictionary will have queue, lastEvent and lastUploadTimestamp detail.
- **unarchive**()
  - This method will unarchive the content from the given path. And also assign values to queue, lastEvent and lastUploadTimestamp from unarchived dictionary detail.
- **append**(_event_)
  - Where _event_ is the collected event to be appended and uploaded depending on the queue batching policies.
- **transfer**()
  - It will transfer ownership of the queue of events to the caller.
- **readyForUpload**()
  - The queue uploading policy is based on:
    - When queue is full -> `_config.uploadWhenMoreThan >= 0 && _queue.count > _config.uploadWhenMoreThan`
    - When queue is old -> ` _config.uploadWhenOlderThan > 0 && _queue.count > 0 && now > _lastUploadTimestamp + _config.uploadWhenOlderThan * 1000`
- **requestUpload**()
  - This method will the upload method from sift class which is used at the time of uploading events, whenever the collected events are ready for upload 

### 4.4 SiftUploader
This module upload the events to the Sift Server. It contains App state events and device properties events.

This class have the following methods:
- **upload**(_events_)
  -  Add the events to batches. If app is in background ithen archive the data. Later it will doUpload method which will upload the collects events to Sift Server.
- **doUpload**()
  -  This method will the upload events to the Sift server .
- **unarchive**()
  - This method will unarchive the content from the given path. And also assign values to batches and numRejects  from unarchived dictionary detail.
- **upload**(_events_)
  - It will upload the collects events to Sift Server.


## 5 Flow Chart

**![{"theme":"neutral","source":"graph TD\n\n    A[Sift] --> B(App State Collector)\n    A --> C(Device Property Collector)\n\n    C & B -->|Collected Events| D[Task Manager]\n    \n    D -->|Add Event| E[[Device Property Queue ]] & F[[App State Queue]]\n\n    E & F -->|Request upload| G([Uploader])\n    \n\n    G -.->|Upload Event| H((Sift Server fa:fa-server))"}](https://lh5.googleusercontent.com/tWoUAHHEIXY1Jggf3bAF0vLS9NOgeoatB2gHlDjWuxH2gSg8lEZ4je8ba6w_Fkf0geROMpIB75rzmkHwNrW7Wx1GQPUgvCEJjLIPoBjWlTKGc_gmwIKWgD-A5_YwpJDYbbWm7VRC "mermaid-graph")**

