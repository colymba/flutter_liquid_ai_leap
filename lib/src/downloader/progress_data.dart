/// Data about download progress.
///
/// Used to track the progress of model downloads.
class ProgressData {
  /// Creates a new [ProgressData].
  const ProgressData({
    required this.bytesDownloaded,
    required this.totalBytes,
    required this.bytesPerSecond,
  });

  /// The number of bytes downloaded so far.
  final int bytesDownloaded;

  /// The total number of bytes to download.
  ///
  /// May be -1 if the total size is unknown.
  final int totalBytes;

  /// The current download speed in bytes per second.
  final int bytesPerSecond;

  /// The download progress as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if the total size is unknown.
  double get progress {
    if (totalBytes <= 0) return 0.0;
    return bytesDownloaded / totalBytes;
  }

  /// The download progress as a percentage (0-100).
  double get progressPercent => progress * 100;

  /// Whether the download is complete.
  bool get isComplete => totalBytes > 0 && bytesDownloaded >= totalBytes;

  /// Formats the download speed as a human-readable string.
  String get formattedSpeed {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
  }

  /// Formats the downloaded size as a human-readable string.
  String get formattedProgress {
    String formatBytes(int bytes) {
      if (bytes < 1024) {
        return '$bytes B';
      } else if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      } else if (bytes < 1024 * 1024 * 1024) {
        return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
      } else {
        return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
      }
    }

    if (totalBytes > 0) {
      return '${formatBytes(bytesDownloaded)} / ${formatBytes(totalBytes)}';
    } else {
      return formatBytes(bytesDownloaded);
    }
  }

  /// Converts this progress data to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'bytes_downloaded': bytesDownloaded,
      'total_bytes': totalBytes,
      'bytes_per_second': bytesPerSecond,
    };
  }

  /// Creates a [ProgressData] from a JSON map.
  factory ProgressData.fromJson(Map<String, dynamic> json) {
    return ProgressData(
      bytesDownloaded: json['bytes_downloaded'] as int,
      totalBytes: json['total_bytes'] as int,
      bytesPerSecond: json['bytes_per_second'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ProgressData) return false;
    return bytesDownloaded == other.bytesDownloaded &&
        totalBytes == other.totalBytes &&
        bytesPerSecond == other.bytesPerSecond;
  }

  @override
  int get hashCode => Object.hash(bytesDownloaded, totalBytes, bytesPerSecond);

  @override
  String toString() {
    return 'ProgressData(${progressPercent.toStringAsFixed(1)}%, $formattedSpeed)';
  }
}
