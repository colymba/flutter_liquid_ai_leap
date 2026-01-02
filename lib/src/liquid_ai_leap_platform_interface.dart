import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'liquid_ai_leap_method_channel.dart';
import 'models/model_manifest.dart';
import 'conversation/model_runner.dart';
import 'downloader/leap_downloader_config.dart';

/// The interface that platform-specific implementations must implement.
///
/// Platform implementations should extend this class and implement the
/// abstract methods to provide platform-specific functionality.
abstract class LiquidAiLeapPlatform extends PlatformInterface {
  /// Constructs a [LiquidAiLeapPlatform].
  LiquidAiLeapPlatform() : super(token: _token);

  static final Object _token = Object();

  static LiquidAiLeapPlatform _instance = MethodChannelLiquidAiLeap();

  /// The default instance of [LiquidAiLeapPlatform] to use.
  ///
  /// Defaults to [MethodChannelLiquidAiLeap].
  static LiquidAiLeapPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LiquidAiLeapPlatform].
  static set instance(LiquidAiLeapPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Downloads and loads a model.
  ///
  /// Platform implementations should download the model if needed and
  /// load it into memory.
  Future<ModelRunner> loadModel({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
    void Function(double progress, int bytesPerSecond)? onProgress,
  });

  /// Downloads a model without loading it.
  ///
  /// If [url] is provided, the model will be downloaded directly from that URL
  /// instead of using the Leap Model Library. This is useful for VL models
  /// and other models not yet available in the library.
  Future<ModelManifest> downloadModel({
    required String model,
    required String quantization,
    String? url,
    LeapDownloaderConfig? config,
    void Function(double progress, int bytesPerSecond)? onProgress,
  });

  /// Checks if a model is cached locally.
  Future<bool> isModelCached({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
  });

  /// Deletes a cached model.
  Future<bool> deleteModel({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
  });

  /// Gets the platform version string.
  Future<String> getPlatformVersion();

  /// Gets the LEAP SDK version.
  Future<String> getSdkVersion();
}
