import '../models/chat_message.dart';
import '../models/generation_options.dart';
import '../models/message_response.dart';
import '../function_calling/leap_function.dart';

/// Represents an active conversation with a loaded model.
///
/// A conversation maintains the message history and provides methods for
/// generating responses. Create conversations from a [ModelRunner].
///
/// ## Example
///
/// ```dart
/// final conversation = await modelRunner.createConversation(
///   systemPrompt: 'You are a helpful assistant.',
/// );
///
/// // Register functions for the model to call
/// await conversation.registerFunction(weatherFunction);
///
/// // Generate streaming responses
/// await for (final response in conversation.generateResponse(
///   message: ChatMessage.user('What is the weather in NYC?'),
/// )) {
///   // Handle response chunks
/// }
///
/// // Access conversation history
/// print('History: ${conversation.history}');
/// ```
abstract class Conversation {
  /// Creates a new [Conversation].
  const Conversation();

  /// The chat message history of this conversation.
  ///
  /// This is a copy of the internal history. Mutations to the returned list
  /// will not affect the conversation.
  ///
  /// The history is updated with the assistant's reply when generation
  /// completes successfully.
  List<ChatMessage> get history;

  /// Registers a function for the model to call.
  ///
  /// The model can request to call registered functions during generation.
  /// Function call requests are returned via [FunctionCallResponse].
  ///
  /// ## Example
  ///
  /// ```dart
  /// await conversation.registerFunction(LeapFunction(
  ///   name: 'get_weather',
  ///   description: 'Get weather for a city',
  ///   parameters: [
  ///     LeapFunctionParameter(
  ///       name: 'city',
  ///       type: LeapFunctionParameterType.string(),
  ///       description: 'The city name',
  ///     ),
  ///   ],
  /// ));
  /// ```
  Future<void> registerFunction(LeapFunction function);

  /// Generates a response to the given message.
  ///
  /// Returns an async stream of [MessageResponse] values as the model
  /// generates tokens. The stream ends with a [CompleteResponse].
  ///
  /// [message] is the message to generate a response to.
  /// [options] are optional generation parameters.
  ///
  /// ## Example
  ///
  /// ```dart
  /// await for (final response in conversation.generateResponse(
  ///   message: ChatMessage.user('Hello!'),
  ///   options: GenerationOptions(temperature: 0.7),
  /// )) {
  ///   switch (response) {
  ///     case ChunkResponse(:final text):
  ///       stdout.write(text);
  ///     case CompleteResponse(:final message, :final stats):
  ///       print('\nDone! ${stats?.tokensPerSecond} tok/s');
  ///   }
  /// }
  /// ```
  ///
  /// Throws [LeapException] if generation fails.
  Stream<MessageResponse> generateResponse({
    required ChatMessage message,
    GenerationOptions? options,
  });

  /// Generates a response to a text message.
  ///
  /// This is a convenience method that wraps the text in a [ChatMessage].
  ///
  /// [text] is the user message text.
  /// [options] are optional generation parameters.
  Stream<MessageResponse> generateTextResponse(
    String text, {
    GenerationOptions? options,
  }) {
    return generateResponse(
      message: ChatMessage.user(text),
      options: options,
    );
  }

  /// Disposes of this conversation and releases resources.
  ///
  /// After calling this method, the conversation should not be used.
  Future<void> dispose();

  /// Exports the conversation history to JSON.
  ///
  /// Returns a list of JSON-serializable maps compatible with the OpenAI
  /// chat completion format.
  List<Map<String, dynamic>> exportToJson() {
    return history.map((message) => message.toJson()).toList();
  }
}
