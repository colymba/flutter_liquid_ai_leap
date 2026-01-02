/// Base class for all LEAP SDK exceptions.
///
/// All errors from the LEAP SDK are wrapped in subclasses of this exception.
sealed class LeapException implements Exception {
  /// Creates a new [LeapException].
  const LeapException(this.message, {this.cause});

  /// A human-readable description of the error.
  final String message;

  /// The underlying cause of this exception, if any.
  final Object? cause;

  @override
  String toString() {
    if (cause != null) {
      return '$runtimeType: $message (caused by: $cause)';
    }
    return '$runtimeType: $message';
  }
}

/// Exception thrown when model loading fails.
///
/// This can occur due to:
/// - Network errors during download
/// - Invalid model file
/// - Insufficient memory
/// - Unsupported model format
class LeapModelLoadingException extends LeapException {
  /// Creates a new [LeapModelLoadingException].
  const LeapModelLoadingException(super.message, {super.cause});
}

/// Exception thrown when generation fails.
///
/// This can occur due to:
/// - Model not loaded
/// - Invalid input
/// - Internal inference error
class LeapGenerationException extends LeapException {
  /// Creates a new [LeapGenerationException].
  const LeapGenerationException(super.message, {super.cause});
}

/// Exception thrown when the prompt exceeds the context length.
///
/// The model has a maximum context length. If the prompt (including
/// conversation history) exceeds this limit, generation cannot proceed.
class LeapPromptExceedsContextException extends LeapException {
  /// Creates a new [LeapPromptExceedsContextException].
  const LeapPromptExceedsContextException(
    super.message, {
    this.promptTokens,
    this.maxTokens,
    super.cause,
  });

  /// The number of tokens in the prompt.
  final int? promptTokens;

  /// The maximum number of tokens allowed.
  final int? maxTokens;

  @override
  String toString() {
    final buffer = StringBuffer('LeapPromptExceedsContextException: $message');
    if (promptTokens != null && maxTokens != null) {
      buffer.write(' (prompt: $promptTokens tokens, max: $maxTokens tokens)');
    }
    if (cause != null) {
      buffer.write(' (caused by: $cause)');
    }
    return buffer.toString();
  }
}

/// Exception thrown when JSON serialization or deserialization fails.
///
/// This can occur when:
/// - Parsing function call arguments
/// - Parsing structured output
/// - Exporting/importing conversation history
class LeapSerializationException extends LeapException {
  /// Creates a new [LeapSerializationException].
  const LeapSerializationException(super.message, {super.cause});
}

/// Exception thrown when constrained generation schema is invalid.
///
/// This can occur when:
/// - The JSON schema is malformed
/// - The schema uses unsupported features
/// - The schema is too complex for the model
class LeapConstrainedGenerationException extends LeapException {
  /// Creates a new [LeapConstrainedGenerationException].
  const LeapConstrainedGenerationException(super.message, {super.cause});
}

/// Exception thrown when function calling encounters an error.
///
/// This can occur when:
/// - The function name is not registered
/// - Required parameters are missing
/// - Parameter types don't match
class LeapFunctionCallException extends LeapException {
  /// Creates a new [LeapFunctionCallException].
  const LeapFunctionCallException(super.message, {super.cause});
}

/// Exception thrown when the platform is not supported.
///
/// The LEAP SDK requires:
/// - iOS 15.0+ or Android API 31+
/// - Physical device (simulator support is limited)
class LeapPlatformException extends LeapException {
  /// Creates a new [LeapPlatformException].
  const LeapPlatformException(super.message, {super.cause});
}
