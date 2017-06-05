# Change Log

## [0.9.7] – 2017-06-05
– Updates event-batching logic

## [0.9.6] – 2017-05-09
– Adds suspend / resume counter for stability

## [0.9.5] – 2017-05-02
- Various stability improvements (KVO and uploader)

## [0.9.4] - 2017-03-07
- Decreases TTL and batch size for device properties collection

## [0.9.3] - 2017-01-26
- Don't include AdSupport headers for IFA

## [0.9.2] - 2017-01-20
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
