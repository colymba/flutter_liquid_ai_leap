import 'chat_message_content.dart';
import 'chat_message_role.dart';
import '../function_calling/leap_function_call.dart';

/// Represents a message in a conversation.
///
/// A chat message consists of a role, content parts, and optional metadata
/// like reasoning content or function calls. The format is compatible with
/// the OpenAI chat completion API.
///
/// ## Example
///
/// ```dart
/// // Create a user message
/// final userMessage = ChatMessage(
///   role: ChatMessageRole.user,
///   content: [TextContent('What is the weather like?')],
/// );
///
/// // Create using convenience factory
/// final quickMessage = ChatMessage.user('Hello!');
///
/// // Create a message with image
/// final imageMessage = ChatMessage(
///   role: ChatMessageRole.user,
///   content: [
///     TextContent('What do you see in this image?'),
///     ImageContent(jpegBytes),
///   ],
/// );
/// ```
class ChatMessage {
  /// Creates a new [ChatMessage].
  ///
  /// [role] specifies the message sender (user, assistant, system, or tool).
  /// [content] is a list of content parts (text, images, or audio).
  /// [reasoningContent] is optional reasoning text from reasoning models.
  /// [functionCalls] are optional function call requests from the model.
  const ChatMessage({
    required this.role,
    required this.content,
    this.reasoningContent,
    this.functionCalls,
  });

  /// Creates a user message with text content.
  ///
  /// This is a convenience factory for creating simple text messages.
  factory ChatMessage.user(String text) {
    return ChatMessage(
      role: ChatMessageRole.user,
      content: [TextContent(text)],
    );
  }

  /// Creates a system message with text content.
  ///
  /// System messages are typically used to set the model's behavior.
  factory ChatMessage.system(String text) {
    return ChatMessage(
      role: ChatMessageRole.system,
      content: [TextContent(text)],
    );
  }

  /// Creates an assistant message with text content.
  ///
  /// This can be used to seed the conversation with example responses.
  factory ChatMessage.assistant(String text) {
    return ChatMessage(
      role: ChatMessageRole.assistant,
      content: [TextContent(text)],
    );
  }

  /// Creates a tool message with function call results.
  ///
  /// Used to provide the results of function calls back to the model.
  factory ChatMessage.tool(String result) {
    return ChatMessage(
      role: ChatMessageRole.tool,
      content: [TextContent(result)],
    );
  }

  /// The role of the message sender.
  final ChatMessageRole role;

  /// The content parts of this message.
  ///
  /// A message can contain multiple content parts, such as text and images
  /// in the same message.
  final List<ChatMessageContent> content;

  /// Optional reasoning content from reasoning models.
  ///
  /// This contains the model's internal reasoning process, typically wrapped
  /// in `<think>` tags. Only populated for models that expose reasoning traces.
  final String? reasoningContent;

  /// Optional function call requests from the model.
  ///
  /// Populated when the model requests to call registered functions.
  final List<LeapFunctionCall>? functionCalls;

  /// Gets the combined text content of this message.
  ///
  /// Extracts all [TextContent] parts and joins them together.
  /// Returns an empty string if there are no text parts.
  String get textContent {
    return content.whereType<TextContent>().map((text) => text.text).join();
  }

  /// Gets all image content parts from this message.
  List<ImageContent> get imageContent {
    return content.whereType<ImageContent>().toList();
  }

  /// Gets all audio content parts from this message.
  List<AudioContent> get audioContent {
    return content.whereType<AudioContent>().toList();
  }

  /// Converts this message to a JSON-serializable map.
  ///
  /// The format is compatible with the OpenAI chat completion API.
  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{
      'role': role.value,
      'content': content.map((c) => c.toJson()).toList(),
    };

    if (reasoningContent != null) {
      json['reasoning_content'] = reasoningContent;
    }

    if (functionCalls != null && functionCalls!.isNotEmpty) {
      json['function_calls'] = functionCalls!.map((fc) => fc.toJson()).toList();
    }

    return json;
  }

  /// Creates a [ChatMessage] from a JSON map.
  ///
  /// The map should follow the OpenAI chat completion API format.
  ///
  /// Throws [FormatException] if the JSON format is invalid.
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final role = ChatMessageRole.fromString(json['role'] as String);

    List<ChatMessageContent> content;
    final rawContent = json['content'];

    if (rawContent is String) {
      // Simple string content
      content = [TextContent(rawContent)];
    } else if (rawContent is List) {
      // Array of content parts
      content = rawContent
          .cast<Map<String, dynamic>>()
          .map(ChatMessageContent.fromJson)
          .toList();
    } else {
      throw FormatException('Invalid content format: $rawContent');
    }

    final reasoningContent = json['reasoning_content'] as String?;

    List<LeapFunctionCall>? functionCalls;
    if (json['function_calls'] != null) {
      functionCalls = (json['function_calls'] as List)
          .cast<Map<String, dynamic>>()
          .map(LeapFunctionCall.fromJson)
          .toList();
    }

    return ChatMessage(
      role: role,
      content: content,
      reasoningContent: reasoningContent,
      functionCalls: functionCalls,
    );
  }

  /// Creates a copy of this message with the given fields replaced.
  ChatMessage copyWith({
    ChatMessageRole? role,
    List<ChatMessageContent>? content,
    String? reasoningContent,
    List<LeapFunctionCall>? functionCalls,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      reasoningContent: reasoningContent ?? this.reasoningContent,
      functionCalls: functionCalls ?? this.functionCalls,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ChatMessage) return false;
    return role == other.role &&
        _listEquals(content, other.content) &&
        reasoningContent == other.reasoningContent &&
        _listEquals(functionCalls, other.functionCalls);
  }

  @override
  int get hashCode => Object.hash(
        role,
        Object.hashAll(content),
        reasoningContent,
        functionCalls != null ? Object.hashAll(functionCalls!) : null,
      );

  @override
  String toString() {
    return 'ChatMessage(role: $role, content: $content)';
  }

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
