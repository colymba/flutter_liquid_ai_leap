/// Liquid AI LEAP Flutter Plugin
///
/// A Flutter plugin wrapper for the Liquid AI LEAP SDK that provides on-device
/// AI inference capabilities using Liquid Foundation Models (LFM) on iOS and
/// Android.
///
/// ## Getting Started
///
/// ```dart
/// import 'package:liquid_ai_leap/liquid_ai_leap.dart';
///
/// // Initialize the plugin
/// final leap = LiquidAiLeap();
///
/// // Load a model
/// final modelRunner = await leap.loadModel(
///   model: 'LFM2-1.2B',
///   quantization: 'Q5_K_M',
///   onProgress: (progress, speed) {
///     print('Download progress: ${(progress * 100).toStringAsFixed(1)}%');
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
///   message: ChatMessage.user('Hello! What can you do?'),
/// )) {
///   switch (response) {
///     case ChunkResponse(:final text):
///       print(text);
///     case CompleteResponse(:final message):
///       print('Complete: ${message.textContent}');
///     default:
///       break;
///   }
/// }
/// ```
///
/// ## Features
///
/// - **On-device inference**: Run AI models locally without network dependency
/// - **Streaming responses**: Get real-time token-by-token generation
/// - **Multimodal support**: Handle text, images, and audio content
/// - **Function calling**: Let the model interact with your app's functions
/// - **Constrained generation**: Generate structured JSON output
///
/// ## Platform Requirements
///
/// ### iOS
/// - iOS 15.0+
/// - Xcode 15.0+
/// - Physical device recommended (3GB+ RAM)
///
/// ### Android
/// - API 31+ (Android 12+)
/// - arm64-v8a ABI support
/// - Physical device recommended (3GB+ RAM)
///
/// ## See Also
///
/// - [LEAP Documentation](https://docs.liquid.ai/leap/edge-sdk/overview)
/// - [Model Library](https://leap.liquid.ai/models)
library liquid_ai_leap;

// Core exports
export 'src/liquid_ai_leap.dart';
export 'src/liquid_ai_leap_platform_interface.dart';

// Model exports
export 'src/models/chat_message.dart';
export 'src/models/chat_message_content.dart';
export 'src/models/chat_message_role.dart';
export 'src/models/generation_options.dart';
export 'src/models/generation_stats.dart';
export 'src/models/message_response.dart';
export 'src/models/model_manifest.dart';

// Conversation exports
export 'src/conversation/conversation.dart';
export 'src/conversation/model_runner.dart';
export 'src/conversation/generation_handler.dart';

// Function calling exports
export 'src/function_calling/leap_function.dart';
export 'src/function_calling/leap_function_call.dart';
export 'src/function_calling/leap_function_parameter.dart';
export 'src/function_calling/leap_function_parameter_type.dart';

// Downloader exports
export 'src/downloader/leap_downloader.dart';
export 'src/downloader/leap_downloader_config.dart';
export 'src/downloader/progress_data.dart';

// Exception exports
export 'src/exceptions/leap_exception.dart';
