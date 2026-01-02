import '../models/chat_message.dart';
import 'conversation.dart';

/// Represents a loaded AI model that can perform generation.
///
/// A model runner is created by loading a model through [LiquidAiLeap].
/// Use it to create conversations and perform text generation.
///
/// ## Example
///
/// ```dart
/// // Load a model
/// final modelRunner = await leap.loadModel(
///   model: 'LFM2-1.2B',
///   quantization: 'Q5_K_M',
/// );
///
/// // Create a conversation
/// final conversation = await modelRunner.createConversation(
///   systemPrompt: 'You are a helpful assistant.',
/// );
///
/// // When done, unload the model to free resources
/// await modelRunner.unload();
/// ```
abstract class ModelRunner {
  /// Creates a new [ModelRunner].
  const ModelRunner();

  /// Creates a new conversation with this model.
  ///
  /// [systemPrompt] is an optional system message to set the model's behavior.
  /// If not provided, the model's default behavior is used.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final conversation = await modelRunner.createConversation(
  ///   systemPrompt: 'You are a travel assistant. Help users plan trips.',
  /// );
  /// ```
  Future<Conversation> createConversation({String? systemPrompt});

  /// Creates a conversation from an existing message history.
  ///
  /// Use this to restore a conversation from persistent storage or to
  /// continue a previous conversation.
  ///
  /// [history] is the list of messages to initialize the conversation with.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Restore from saved history
  /// final savedHistory = await loadHistory();
  /// final conversation = await modelRunner.createConversationFromHistory(
  ///   savedHistory,
  /// );
  /// ```
  Future<Conversation> createConversationFromHistory(List<ChatMessage> history);
}
