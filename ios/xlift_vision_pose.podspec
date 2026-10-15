Pod::Spec.new do |s|
  s.name             = 'xlift_vision_pose'
  s.version          = '0.1.0'
  s.summary          = 'Apple Vision 3D body pose bridge.'
  s.description      = 'Runs VNDetectHumanBodyPose3DRequest over a video file and returns per-frame joints.'
  s.homepage         = 'https://github.com/gall1314/xlift_vision_pose'
  s.license          = { :type => 'MIT' }
  s.author           = { 'Gal' => 'gal@xlift.app' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '13.0'
  s.swift_version    = '5.0'
  s.frameworks       = 'Vision', 'AVFoundation', 'CoreMedia', 'CoreVideo'
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386'
  }
end
