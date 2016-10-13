## How to release

We use semantic versioning, and release the SDK through both CocoaPods
and Carthage.  Here are the basic steps for releasing SDK:

* Open `Sift/Sift.m` and update `_sdkVersion` property.

* Update `spec.version` of `Sift.podspec`.

* Update `CHANGELOG.md`.

* (Optional) Update `spec.public_header_files` or `spec.ios.frameworks`
  of `Sift.podspec` (if you have new public headers or depend on new
  frameworks).

* Create a git tag for the release.


### Things to do after release

You will need to update `HelloSift` app to the new release:

* Enter `HelloSift` directory.

* Update `Cartfile` to the new version.

* Run `carthage update`.

* Check in changes to `Cartfile` and `Cartfile.resolved` file.


### How to test a release candidate before release it

You may test a release candidate with `HelloSift`:

* Enter `HelloSift` directory.

* Change contents of `Cartfile` to something like:
  ```
  github "SiftScience/sift-ios" "master"
  ```

* Run `carthage update` (but don't commit changes to `Cartfile` and
  `Cartfile.resolved` file).
