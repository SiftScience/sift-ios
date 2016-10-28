Pod::Spec.new do |spec|
  spec.name = 'Sift'
  spec.version = '0.1.0'
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
  spec.ios.deployment_target = '8.0'

  # Build settings
  spec.ios.frameworks = [
    'AdSupport',
    'CoreLocation',
    'CoreMotion',
    'CoreTelephony',
    'Foundation',
    'UIKit',
  ]

  # File patterns
  spec.source_files = 'Sift/*.{h,m}'
  spec.public_header_files = [
    'Sift/SFCompatibility.h',
    'Sift/SFEvent.h',
    'Sift/SFQueueConfig.h',
    'Sift/Sift.h',
  ]
end
