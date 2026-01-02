import '../models/model_manifest.dart';
import '../conversation/model_runner.dart';
import 'leap_downloader_config.dart';

/// Callback for download progress updates.
///
/// [progress] is a value between 0.0 and 1.0 representing completion.
/// [bytesPerSecond] is the current download speed.
typedef DownloadProgressCallback = void Function(
  double progress,
  int bytesPerSecond,
);

/// Downloads and loads LEAP models.
///
/// The downloader handles fetching model files from the LEAP Model Library,
/// caching them locally, and loading them into memory.
///
/// ## Example
///
/// ```dart
/// final downloader = LeapDownloader(
///   config: LeapDownloaderConfig(
///     saveDirectory: '/path/to/cache',
///   ),
/// );
///
/// // Load a model (downloads if needed)
/// final runner = await downloader.loadModel(
///   model: 'LFM2-1.2B',
///   quantization: 'Q5_K_M',
///   onProgress: (progress, speed) {
///     print('${(progress * 100).toStringAsFixed(1)}% at $speed bytes/s');
///   },
/// );
///
/// // Or just download without loading
/// final manifest = await downloader.downloadModel(
///   model: 'LFM2-1.2B',
///   quantization: 'Q5_K_M',
/// );
/// ```
abstract class LeapDownloader {
  /// Creates a new [LeapDownloader] with the given configuration.
  const LeapDownloader({this.config = const LeapDownloaderConfig()});

  /// The configuration for this downloader.
  final LeapDownloaderConfig config;

  /// Downloads and loads a model from the LEAP Model Library.
  ///
  /// If the model is already cached locally, it will be loaded from disk
  /// without downloading.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  /// [onProgress] is called with download progress updates.
  ///
  /// Returns a [ModelRunner] that can be used to create conversations.
  ///
  /// Throws [LeapModelLoadingException] if loading fails.
  Future<ModelRunner> loadModel({
    required String model,
    required String quantization,
    DownloadProgressCallback? onProgress,
  });

  /// Downloads a model without loading it into memory.
  ///
  /// Useful for pre-downloading models for offline use.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  /// [onProgress] is called with download progress updates.
  ///
  /// Returns a [ModelManifest] with information about the downloaded model.
  ///
  /// Throws [LeapModelLoadingException] if download fails.
  Future<ModelManifest> downloadModel({
    required String model,
    required String quantization,
    DownloadProgressCallback? onProgress,
  });

  /// Checks if a model is already cached locally.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  ///
  /// Returns `true` if the model is available locally.
  Future<bool> isModelCached({
    required String model,
    required String quantization,
  });

  /// Deletes a cached model.
  ///
  /// [model] is the model identifier (e.g., 'LFM2-1.2B').
  /// [quantization] is the quantization level (e.g., 'Q5_K_M').
  ///
  /// Returns `true` if the model was deleted, `false` if it wasn't cached.
  Future<bool> deleteModel({
    required String model,
    required String quantization,
  });

  /// Gets information about cached models.
  ///
  /// Returns a list of manifests for all cached models.
  Future<List<ModelManifest>> getCachedModels();

  /// Clears all cached models.
  ///
  /// Returns the number of models deleted.
  Future<int> clearCache();
}
