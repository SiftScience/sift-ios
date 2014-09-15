Sift Science iOS SDK
============
This repository includes the Sift Science iOS SDK, a small static library that can be called from any iOS application to send user device information to Sift Science. With the Sift SDK, you can collect information such as:
* Identifier for vendor
* Device model
* Device name
* System name
* Default language
* Jailbreak status
* User GPS location

Usage
============
To check for device info changes and send updates to Sift, add the following line:
```
  [[[SFTSiftDeviceInfo alloc] initWithUser:[SFTUserStore user] apiKey:API_KEY] updateInfo];
```
Here, API_KEY is your beacon api key.

Developer Setup
============
Clone the iOS Repo:
```
	git clone git@github.com:SiftScience/sift-ios.git
```
To install dependencies and setup the project, run:
```
	make setup
```
To modify the sdk, open Xcode and select File -> Open -> SiftIOS.xcworkspace.
To modify the demo app, open Xcode and select File -> Open -> CatsNHacks.xcworkspace.
To run the demo app, open CatsNHacks in Xcode and press the "play" button in the top left corner of the window.
