/// A handle to control ongoing generation.
///
/// Use this handle to stop generation before it completes naturally.
///
/// ## Example
///
/// ```dart
/// final handler = conversation.startGeneration(
///   message: ChatMessage.user('Tell me a long story'),
///   onResponse: (response) => handleResponse(response),
/// );
///
/// // Stop generation early if needed
/// await Future.delayed(Duration(seconds: 5));
/// handler.stop();
/// ```
abstract class GenerationHandler {
  /// Creates a new [GenerationHandler].
  const GenerationHandler();

  /// Stops the ongoing generation.
  ///
  /// After calling stop, no more responses will be emitted.
  /// The model will clean up resources and the generation will complete
  /// with a [CompleteResponse] with [GenerationFinishReason.cancelled].
  void stop();
}

/// A no-op generation handler for testing or when no generation is active.
class NoOpGenerationHandler extends GenerationHandler {
  /// Creates a new [NoOpGenerationHandler].
  const NoOpGenerationHandler();

  @override
  void stop() {
    // No-op
  }
}
