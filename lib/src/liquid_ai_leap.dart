import 'liquid_ai_leap_platform_interface.dart';
import 'models/model_manifest.dart';
import 'conversation/model_runner.dart';
import 'downloader/leap_downloader_config.dart';

/// The main entry point for the Liquid AI LEAP Flutter plugin.
///
/// Use this class to load models, create conversations, and perform
/// on-device AI inference.
///
/// ## Example
///
/// ```dart
/// import 'package:liquid_ai_leap/liquid_ai_leap.dart';
///
/// // Create an instance
/// final leap = LiquidAiLeap();
///
/// // Load a model
/// final modelRunner = await leap.loadModel(
///   model: 'LFM2-1.2B',
///   quantization: 'Q5_K_M',
///   onProgress: (progress, speed) {
///     print('Download: ${(progress * 100).toStringAsFixed(1)}%');
///   },
/// );
///
/// // Create a conversation
/// final conversation = modelRunner.createConversation(
///   systemPrompt: 'You are a helpful assistant.',
/// );
///
/// // Generate a response
/// await for (final response in conversation.generateResponse(
///   message: ChatMessage.user('Hello!'),
/// )) {
///   switch (response) {
///     case ChunkResponse(:final text):
///       stdout.write(text);
///     case CompleteResponse(:final message):
///       print('\nDone!');
///   }
/// }
/// ```
class LiquidAiLeap {
  /// Creates a new [LiquidAiLeap] instance.
  ///
  /// [config] is optional configuration for the model downloader.
  LiquidAiLeap({LeapDownloaderConfig? config}) : _config = config;

  final LeapDownloaderConfig? _config;

  /// Downloads and loads a model from the LEAP Model Library.
  ///
  /// If the model is already cached locally, it will be loaded from disk
  /// without downloading.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// See the [LEAP Model Library](https://leap.liquid.ai/models) for available models.
  ///
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  /// Different quantizations trade off between model size, speed, and quality.
  ///
  /// [onProgress] is an optional callback for download progress updates.
  /// The first parameter is progress (0.0 to 1.0), the second is speed in bytes/s.
  ///
  /// [config] overrides the default downloader configuration for this request.
  ///
  /// Returns a [ModelRunner] that can be used to create conversations and
  /// perform generation.
  ///
  /// Throws [LeapModelLoadingException] if loading fails.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final runner = await leap.loadModel(
  ///   model: 'LFM2-1.2B',
  ///   quantization: 'Q5_K_M',
  ///   onProgress: (progress, speed) {
  ///     final percent = (progress * 100).toStringAsFixed(1);
  ///     final speedMB = (speed / 1024 / 1024).toStringAsFixed(1);
  ///     print('Downloading: $percent% at $speedMB MB/s');
  ///   },
  /// );
  /// ```
  Future<ModelRunner> loadModel({
    required String model,
    required String quantization,
    void Function(double progress, int bytesPerSecond)? onProgress,
    LeapDownloaderConfig? config,
  }) {
    return LiquidAiLeapPlatform.instance.loadModel(
      model: model,
      quantization: quantization,
      config: config ?? _config,
      onProgress: onProgress,
    );
  }

  /// Downloads a model without loading it into memory.
  ///
  /// Useful for pre-downloading models for offline use or to check
  /// model metadata.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  /// [onProgress] is an optional callback for download progress updates.
  /// [config] overrides the default downloader configuration.
  ///
  /// Returns a [ModelManifest] with information about the downloaded model.
  ///
  /// If [url] is provided, the model will be downloaded directly from that URL.
  /// If [urls] is provided (`List<String>`), multiple files will be downloaded (e.g. split GGUF + mmproj).
  /// This is useful for VL (vision-language) models and other models not yet available in the library.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Pre-download a model from Leap Model Library
  /// final manifest = await leap.downloadModel(
  ///   model: 'LFM2-1.2B',
  ///   quantization: 'Q5_K_M',
  /// );
  /// print('Downloaded to: ${manifest.localModelPath}');
  ///
  /// // Download a VL model directly from URLs (split files)
  /// final vlManifest = await leap.downloadModel(
  ///   model: 'InternVL3-2B',
  ///   quantization: 'Q4_K_S',
  ///   urls: [
  ///     'https://huggingface.co/.../internvl3-2b-instruct-q4_k_s.gguf',
  ///     'https://huggingface.co/.../mmproj-internvl3-2b-instruct-f16.gguf',
  ///   ],
  /// );
  /// ```
  Future<ModelManifest> downloadModel({
    required String model,
    required String quantization,
    String? url,
    List<String>? urls,
    void Function(double progress, int bytesPerSecond)? onProgress,
    LeapDownloaderConfig? config,
  }) {
    return LiquidAiLeapPlatform.instance.downloadModel(
      model: model,
      quantization: quantization,
      url: url,
      urls: urls,
      config: config ?? _config,
      onProgress: onProgress,
    );
  }

  /// Checks if a model is already cached locally.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  /// [config] overrides the default downloader configuration.
  ///
  /// Returns `true` if the model is available locally.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final isCached = await leap.isModelCached(
  ///   model: 'LFM2-1.2B',
  ///   quantization: 'Q5_K_M',
  /// );
  /// if (!isCached) {
  ///   print('Model needs to be downloaded');
  /// }
  /// ```
  Future<bool> isModelCached({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
  }) {
    return LiquidAiLeapPlatform.instance.isModelCached(
      model: model,
      quantization: quantization,
      config: config ?? _config,
    );
  }

  /// Deletes a cached model.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  /// [config] overrides the default downloader configuration.
  ///
  /// Returns `true` if the model was deleted, `false` if it wasn't cached.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final deleted = await leap.deleteModel(
  ///   model: 'LFM2-1.2B',
  ///   quantization: 'Q5_K_M',
  /// );
  /// print(deleted ? 'Model deleted' : 'Model was not cached');
  /// ```
  Future<bool> deleteModel({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
  }) {
    return LiquidAiLeapPlatform.instance.deleteModel(
      model: model,
      quantization: quantization,
      config: config ?? _config,
    );
  }

  /// Gets the platform version string.
  ///
  /// Returns a string like 'iOS 15.0' or 'Android 12'.
  Future<String> getPlatformVersion() {
    return LiquidAiLeapPlatform.instance.getPlatformVersion();
  }

  /// Gets the LEAP SDK version.
  ///
  /// Returns the version of the native LEAP SDK.
  Future<String> getSdkVersion() {
    return LiquidAiLeapPlatform.instance.getSdkVersion();
  }
}
