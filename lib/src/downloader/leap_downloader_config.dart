/// Configuration for the LEAP model downloader.
///
/// Use this to customize where models are stored and how downloads
/// are validated.
///
/// ## Example
///
/// ```dart
/// final config = LeapDownloaderConfig(
///   saveDirectory: '/path/to/models',
///   validateChecksum: true,
/// );
///
/// final downloader = LeapDownloader(config: config);
/// ```
class LeapDownloaderConfig {
  /// Creates a new [LeapDownloaderConfig].
  ///
  /// [saveDirectory] is the directory where models will be saved.
  /// Defaults to a platform-specific cache directory.
  ///
  /// [validateChecksum] enables SHA256 validation of downloaded files.
  /// Defaults to `true` for security.
  const LeapDownloaderConfig({
    this.saveDirectory,
    this.validateChecksum = true,
  });

  /// The directory where downloaded models are saved.
  ///
  /// If not specified, a platform-specific default is used:
  /// - iOS: App's Documents directory
  /// - Android: App's external files directory
  final String? saveDirectory;

  /// Whether to validate the SHA256 checksum of downloaded files.
  ///
  /// Enabled by default for security. Disable only if you have other
  /// means of validating file integrity.
  final bool validateChecksum;

  /// Creates a copy of this config with the given fields replaced.
  LeapDownloaderConfig copyWith({
    String? saveDirectory,
    bool? validateChecksum,
  }) {
    return LeapDownloaderConfig(
      saveDirectory: saveDirectory ?? this.saveDirectory,
      validateChecksum: validateChecksum ?? this.validateChecksum,
    );
  }

  /// Converts this config to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      if (saveDirectory != null) 'save_directory': saveDirectory,
      'validate_checksum': validateChecksum,
    };
  }

  /// Creates a [LeapDownloaderConfig] from a JSON map.
  factory LeapDownloaderConfig.fromJson(Map<String, dynamic> json) {
    return LeapDownloaderConfig(
      saveDirectory: json['save_directory'] as String?,
      validateChecksum: json['validate_checksum'] as bool? ?? true,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LeapDownloaderConfig) return false;
    return saveDirectory == other.saveDirectory &&
        validateChecksum == other.validateChecksum;
  }

  @override
  int get hashCode => Object.hash(saveDirectory, validateChecksum);

  @override
  String toString() {
    return 'LeapDownloaderConfig(saveDirectory: $saveDirectory, '
        'validateChecksum: $validateChecksum)';
  }
}
