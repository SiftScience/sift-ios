Pod::Spec.new do |spec|
  spec.name = 'Sift'
  spec.version = '2.1.9'
  spec.authors = 'Sift Science'
  spec.license = {
    :type => 'MIT',
    :file => 'LICENSE',
  }
  spec.homepage = 'https://github.com/SiftScience/sift-ios'
  spec.source = {
    :git => 'https://github.com/SiftScience/sift-ios.git',
    :tag => "v#{spec.version.to_s}",
  }
  spec.summary = 'Machine learning fraud detection and prevention'

  # Platform
  spec.platform = :ios
  spec.ios.deployment_target = '12.0'
  spec.ios.resource_bundles = {"Sift" => ["PrivacyInfo.xcprivacy"]}

  # Build settings
  spec.ios.frameworks = [
    'CoreLocation',
    'CoreMotion',
    'CoreTelephony',
    'Foundation',
    'UIKit',
  ]

  # File patterns
  spec.source_files = 'Sift/*.{h,m}', 'Sift/Vendor/*.{h,m}'
  spec.public_header_files = [
    'Sift/SiftCompatibility.h',
    'Sift/SiftEvent.h',
    'Sift/SiftQueueConfig.h',
    'Sift/Sift.h',
  ]
end
