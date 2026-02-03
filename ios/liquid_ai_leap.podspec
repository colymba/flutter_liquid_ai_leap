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

  # LEAP SDK - Vendored XCFrameworks
  # Pre-built frameworks from https://github.com/Liquid4All/leap-ios/releases
  # Download using: ./scripts/download_frameworks.sh
  s.vendored_frameworks = 'Frameworks/LeapSDK.xcframework', 'Frameworks/LeapModelDownloader.xcframework'
  
  # Prepare command to download frameworks if they don't exist
  s.prepare_command = <<-CMD
    if [ ! -d "Frameworks/LeapSDK.xcframework" ] || [ ! -d "Frameworks/LeapModelDownloader.xcframework" ]; then
      echo "⚠️  LeapSDK frameworks not found. Downloading..."
      if [ -f "../../scripts/download_frameworks.sh" ]; then
        bash ../../scripts/download_frameworks.sh v0.9.2
      else
        echo "❌ Error: download_frameworks.sh not found"
        exit 1
      fi
    else
      echo "✅ LeapSDK frameworks found"
    fi
  CMD
end
