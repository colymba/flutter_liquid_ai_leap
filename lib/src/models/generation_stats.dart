/// Statistics about a generation request.
///
/// Provides information about token usage and performance metrics
/// for a completed generation.
class GenerationStats {
  /// Creates a new [GenerationStats].
  const GenerationStats({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
    required this.tokensPerSecond,
  });

  /// The number of tokens in the input prompt.
  final int promptTokens;

  /// The number of tokens generated in the response.
  final int completionTokens;

  /// The total number of tokens (prompt + completion).
  final int totalTokens;

  /// The generation speed in tokens per second.
  final double tokensPerSecond;

  /// Converts this stats object to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
      'tokens_per_second': tokensPerSecond,
    };
  }

  /// Creates a [GenerationStats] from a JSON map.
  factory GenerationStats.fromJson(Map<String, dynamic> json) {
    return GenerationStats(
      promptTokens: json['prompt_tokens'] as int,
      completionTokens: json['completion_tokens'] as int,
      totalTokens: json['total_tokens'] as int,
      tokensPerSecond: (json['tokens_per_second'] as num).toDouble(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GenerationStats) return false;
    return promptTokens == other.promptTokens &&
        completionTokens == other.completionTokens &&
        totalTokens == other.totalTokens &&
        tokensPerSecond == other.tokensPerSecond;
  }

  @override
  int get hashCode => Object.hash(
        promptTokens,
        completionTokens,
        totalTokens,
        tokensPerSecond,
      );

  @override
  String toString() {
    return 'GenerationStats(prompt: $promptTokens, completion: $completionTokens, '
        'total: $totalTokens, speed: ${tokensPerSecond.toStringAsFixed(1)} tok/s)';
  }
}

/// The reason why generation finished.
enum GenerationFinishReason {
  /// The model decided to stop generating.
  stop('stop'),

  /// The generation exceeded the maximum context length.
  exceedContext('exceed_context'),

  /// Generation was cancelled by the user.
  cancelled('cancelled'),

  /// Generation finished due to an error.
  error('error');

  /// Creates a new [GenerationFinishReason] with the given string [value].
  const GenerationFinishReason(this.value);

  /// The string representation of this finish reason.
  final String value;

  /// Creates a [GenerationFinishReason] from its string representation.
  factory GenerationFinishReason.fromString(String value) {
    return GenerationFinishReason.values.firstWhere(
      (reason) => reason.value == value,
      orElse: () => GenerationFinishReason.stop,
    );
  }

  @override
  String toString() => value;
}
