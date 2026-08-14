Pod::Spec.new do |s|
  s.name             = 'GazePointSDK-macOS'
  s.version          = '2.2.0'
  s.summary          = 'GazePoint SDK for macOS — eye tracking and gaze point detection'
  s.description      = <<-DESC
    Native macOS GazePoint SDK using Vision framework for gaze estimation.
    Supports real-time gaze tracking, head pose compensation, and blink detection.
  DESC
  s.homepage         = 'https://github.com/Tareq-Ghassan/GazePointSDK-macOS'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'Tareq Abu Saleh' => 'https://github.com/Tareq-Ghassan' }
  s.source           = {
    :git => 'https://github.com/Tareq-Ghassan/GazePointSDK-macOS.git',
    :tag => s.version.to_s
  }
  s.source_files     = 'Sources/GazePointSDK/**/*.swift'
  s.osx.deployment_target = '13.0'
  s.swift_version    = '6.0'
  s.frameworks       = 'Vision', 'AppKit', 'AVFoundation', 'CoreMedia', 'QuartzCore'
end
