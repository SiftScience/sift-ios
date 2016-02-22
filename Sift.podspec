Pod::Spec.new do |s|
  s.name = 'Sift'
  s.version = '0.1.0-alpha.1'
  s.license = 'MIT'
  s.summary = 'Machine learning fraud detection and prevention'
  s.authors = 'Sift Science'
  s.homepage = 'https://siftscience.com'
  s.source = { :git => 'https://github.com/SiftScience/sift-ios.git', :tag => s.version.to_s }

  s.platform = :ios
  s.ios.deployment_target = '7.0'
  s.requires_arc = true
  s.public_header_files = 'Sift/{SFEvent,SFQueueConfig,Sift}.h'
  s.source_files = 'Sift/*.{h,m}'
  s.ios.frameworks = 'CoreLocation'
end
