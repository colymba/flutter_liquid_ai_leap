#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint liquid_ai_leap.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'liquid_ai_leap'
  s.version          = '0.1.0'
  s.summary          = 'Flutter plugin wrapper for the Liquid AI LEAP SDK'
  s.description      = <<-DESC
A Flutter plugin that provides on-device AI inference capabilities using
Liquid Foundation Models (LFM) via the Liquid AI LEAP SDK.
                       DESC
  s.homepage         = 'https://github.com/Liquid4All/liquid_ai_leap'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Liquid AI' => 'support@liquid.ai' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform         = :ios, '15.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'

  # LEAP SDK dependency via Swift Package Manager
  # The SDK is added via Swift Package Manager in the example app
  # See: https://github.com/Liquid4All/leap-ios
  # 
  # To add the dependency:
  # 1. In Xcode: File -> Add Package Dependencies
  # 2. Enter: https://github.com/Liquid4All/leap-ios.git
  # 3. Select version 0.7.0 or newer
  # 4. Add LeapSDK and optionally LeapModelDownloader
end
