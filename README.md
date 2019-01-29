## Sift iOS SDK

### Integration guide

Here is how to integrate with Sift iOS SDK into your Objective-C iOS app
project (for Swift projects the steps are pretty similar).

#### Installing the library

You may get the SDK into your iOS project through either [CocoaPods](http://cocoapods.org/)
or [Carthage](https://github.com/Carthage/Carthage).

Through CocoaPods:

* Add this to your `Podfile`: `pod 'Sift'` (this uses the latest
  version).

* Run `pod install`.

Through Carthage:

* Add this to your `Cartfile`: `github "SiftScience/sift-ios"` (this
  uses the latest version).

* Run `carthage update`.

Recommended steps:

* Add this to your application's `Info.plist` file:

  ```
  <key>LSApplicationQueriesSchemes</key>
  <array>
    <string>cydia</string>
  </array>
  ```

  We detect jailbroken devices with various signals and one of them is
  whether Cydia is installed.  Since iOS 9, you have to whitelist URL
  schemes you would like to check, and this just adds Cydia to the list.

#### Initializing the library

The SDK works in the background and so you have to initialize it when
your app starts.  It usually makes most sense to initialize the SDK in
`application:didFinishLaunchingWithOptions:`.

Here is what you would do within `AppDelegate.m`:

* Add `#import "Sift/Sift.h"`.

* Add the `application:didFinishLaunchingWithOptions:` instance method
  if it doesn't exist, and insert this code snippet (replacing the placeholder
  strings with your Sift account credentials):

  ```
  Sift *sift = [Sift sharedInstance];
  [sift setAccountId:@"YOUR_ACCOUNT_ID"];
  [sift setBeaconKey:@"YOUR_JAVASCRIPT_SNIPPET_KEY"];
  ```

* (Recommended) If your app uses motion sensors (accelerometer, gyro, or
  magnetometer), and you want to send motion data to Sift, add this line:
  ```
  [sift setAllowUsingMotionSensors:YES];
  ```
  This will enable the SDK to occasionally collect motion data in the
  background.
  
* If your app uses user location data but you do not want send it to
  Sift, add this line:
  ```
  [sift setDisallowCollectingLocationData:YES];
  ```

#### Tracking users

Sift needs the user ID to track the user using this app. Once the user ID
is available (for example, after user has logged in), please set the
user ID:

```
[[Sift sharedInstance] setUserId:@"USER_ID"];
```

If a user logs out, unset the user ID by invoking:

```
[[Sift sharedInstance] unsetUserId];
```

### License

The Sift iOS SDK is distributed under the MIT license. See the file LICENSE for details.

The Sift iOS SDK  includes Charcoal Design's GZIP library, distributed under the permissive zlib license.  See the files Sift/Vendor/NSData+GZIP.h and Sift/Vendor/NSData+GZIP.m for details.
