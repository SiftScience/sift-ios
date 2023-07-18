# Change Log

## [2.1.3] - 2023-07-17
### Removed
- Removing submodule HackerNewsReader dependency

## [2.1.2] - 2023-06-14
### Fixed warnings related to following
- A function declaration without a prototype is deprecated in all version of C
- The iOS deployment target is set to 9. But the range of supported deployment version is 12. to 16.4.99
- 'TARGET_OS_MACCATALYST' is not defined , evaluates to 0.
- 'archiveRootObject:toFile:' is deprecated: first deprecated in iOS 12.0 - Use +archivedDataWithRootObject:requiringSecureCoding:error: and -writeToURL:options:error: instead
- 'unarchiveObjectWithFile:' is deprecated: first deprecated in iOS 12.0 - Use +unarchivedObjectOfClass:fromData:error: instead
- 'subscriberCellularProvider' is deprecated: first deprecated in iOS 12.0 , Replace 'subscriberCellularProvider' with 'serviceSubscriberCellularProviders'


## [2.1.1] - 2022-06-03
### Added

### Changed

### Removed
Deprecated fields


## [2.1.0] - 2021-08-02
### Added
- Adding a new public method collect() to collect mobile events on demand

### Changed

### Removed

## [2.0.4] - 2021-07-22
### Added

### Changed
- Fixes SwiftPM build error for unsupported app extensions #100

### Removed

## [2.0.3] - 2021-06-29
### Added
Create PROPOSETECHNICIALDESIGNDOC.md
Add modules to DESIGNDOC.md
Add images from /Images folder to Git
Create DESIGNDOC.md
Create PROPOSETECHNICIALDESIGNDOC.md

### Changed
Swift package manager usability
Changes in DESIGNDOC.md
Update package and sift_ios file

### Removed

## [2.0.2] - 2020-12-07
### Added
- Fixed warning and Error related to MacCatalyst
- Fix Security Concern from converting Strings to Signed Integers for ipv6
- Create Swift package manager

### Changed
- Upgrade SDK target deployment version
- Improved stability and test coverage 

### Removed
- Remove all warnings which gets generated during build

## [2.0.1] - 2020-03-10
### Removed
- Remove all warnings which gets generated during build

## [2.0.0] - 2020-02-25
### Changed
- Update README for sift rebrand 
- Rename classes to remove SF reserve keyword from their names

## [1.0.1] - 2018-07-17
### Removed
- Removes fork() check

## [1.0.0] - 2018-05-24
### Added
- Adds unsetUserId and fix userId NPE

## [0.9.11] - 2017-12-11
### Added
- Better retry mechanics for errors

## [0.9.10] - 2017-09-07
### Added
- Fixes iOS 11 crasher

## [0.9.9] - 2017-08-17
### Added
- Excludes NaN and Infinity values from JSON body

## [0.9.8] – 2017-07-17
### Added
- Adds sdk_version to app state events

### Changed
- Query UIApplication on UI thread

## [0.9.7] – 2017-06-05
### Changed
- Updates event-batching logic

## [0.9.6] – 2017-05-09
### Added
- Adds suspend / resume counter for stability

## [0.9.5] – 2017-05-02
### Changed
- Various stability improvements (KVO and uploader)

## [0.9.4] - 2017-03-07
### Added
- Add more defensive checks before deferencing from batches

### Changed
- Decreases TTL and batch size for device properties collection

## [0.9.3] - 2017-01-26
### Removed
- Remove AdSupport headers for IFA

## [0.9.2] - 2017-01-20
### Changed
- Reduces backup aggressiveness to eliminate potential race in background thread

## [0.9.1] - 2016-11-23
### Added
- Adds gzip compression to event body
- Adds location configuration to Sift.h

## [0.9.0] - 2016-11-01
### Added
- Collect app states, motion sensor data, location, and more
- Send app version and SDK version back to Sift
- Add samples/HackerNewsReader and integration guide

### Changed
- Refine conditions of when to collect data
- Add rate limits to data collector
- Use structured schema for collected data
- Use identifier for vendor for installation ID
- Add back advertising identifier collection

## [0.1.2] - 2016-03-28
### Added
- Allow user assign another queue as the default queue

### Changed
- Make SDK log less

## [0.1.1] - 2016-03-24
### Removed
- Remove advertising identifier collection

## [0.1.0] - 2016-03-16
### Added
- Implement the core part of the SDK (event batching and uploading)
- Collect device properties
- Support CocoaPods and Carthage
- Add demo app HelloSift
