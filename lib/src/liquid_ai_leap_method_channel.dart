import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'liquid_ai_leap_platform_interface.dart';
import 'models/model_manifest.dart';
import 'models/chat_message.dart';
import 'models/chat_message_content.dart';
import 'models/chat_message_role.dart';
import 'models/generation_options.dart';
import 'models/generation_stats.dart';
import 'models/message_response.dart';
import 'function_calling/leap_function.dart';
import 'function_calling/leap_function_call.dart';
import 'conversation/model_runner.dart';
import 'conversation/conversation.dart';
import 'downloader/leap_downloader_config.dart';

/// An implementation of [LiquidAiLeapPlatform] that uses method channels.
///
/// This class communicates with the native iOS and Android implementations
/// via Flutter's MethodChannel mechanism.
class MethodChannelLiquidAiLeap extends LiquidAiLeapPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('ai.liquid.leap/plugin');

  /// Map of active callback IDs to their stream controllers.
  final Map<String, StreamController<MessageResponse>> _streamControllers = {};

  /// Map of active progress callbacks.
  final Map<String, void Function(double, int)> _progressCallbacks = {};

  /// Counter for generating unique callback IDs.
  int _callbackIdCounter = 0;

  /// Constructor that sets up method call handler for callbacks.
  MethodChannelLiquidAiLeap() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// Handles method calls from the native platform.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onDownloadProgress':
        final callbackId = call.arguments['callbackId'] as String;
        final progress = call.arguments['progress'] as double;
        final bytesPerSecond = call.arguments['bytesPerSecond'] as int;
        _progressCallbacks[callbackId]?.call(progress, bytesPerSecond);
        return;

      case 'onGenerationResponse':
        final callbackId = call.arguments['callbackId'] as String;
        final controller = _streamControllers[callbackId];
        if (controller == null || controller.isClosed) return;

        final type = call.arguments['type'] as String;
        switch (type) {
          case 'chunk':
            final text = call.arguments['text'] as String;
            controller.add(ChunkResponse(text));

          case 'reasoning_chunk':
            final text = call.arguments['text'] as String;
            controller.add(ReasoningChunkResponse(text));

          case 'audio_sample':
            final samples = (call.arguments['samples'] as List).cast<double>();
            final sampleRate = call.arguments['sampleRate'] as int? ?? 16000;
            controller.add(AudioSampleResponse(
              samples: samples,
              sampleRate: sampleRate,
            ));

          case 'function_call':
            final functionCalls = (call.arguments['functionCalls'] as List)
                .map((e) => _parseFunctionCall(e as Map))
                .toList();
            controller.add(FunctionCallResponse(functionCalls));

          case 'complete':
            final message = _parseChatMessage(call.arguments['message'] as Map);
            final finishReasonStr = call.arguments['finishReason'] as String;
            final finishReason =
                GenerationFinishReason.fromString(finishReasonStr);
            final stats = _parseStats(call.arguments['stats'] as Map?);
            controller.add(CompleteResponse(
              message: message,
              finishReason: finishReason,
              stats: stats,
            ));
            await controller.close();
            _streamControllers.remove(callbackId);

          case 'error':
            final error = call.arguments['error'] as String;
            controller.addError(Exception(error));
            await controller.close();
            _streamControllers.remove(callbackId);
        }
        return;
    }
  }

  /// Generates a unique callback ID.
  String _generateCallbackId() {
    _callbackIdCounter++;
    return 'callback_$_callbackIdCounter';
  }

  @override
  Future<String> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version ?? 'Unknown';
  }

  @override
  Future<String> getSdkVersion() async {
    final version = await methodChannel.invokeMethod<String>('getSdkVersion');
    return version ?? 'Unknown';
  }

  @override
  Future<ModelRunner> loadModel({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
    void Function(double progress, int bytesPerSecond)? onProgress,
  }) async {
    String? progressCallbackId;
    if (onProgress != null) {
      progressCallbackId = _generateCallbackId();
      _progressCallbacks[progressCallbackId] = onProgress;
    }

    try {
      final result = await methodChannel.invokeMethod<Map>('loadModel', {
        'model': model,
        'quantization': quantization,
        if (config?.saveDirectory != null)
          'saveDirectory': config!.saveDirectory,
        if (progressCallbackId != null)
          'progressCallbackId': progressCallbackId,
      });

      final runnerId = result!['runnerId'] as String;
      return _MethodChannelModelRunner(
        runnerId: runnerId,
        channel: methodChannel,
        streamControllers: _streamControllers,
        generateCallbackId: _generateCallbackId,
      );
    } finally {
      if (progressCallbackId != null) {
        _progressCallbacks.remove(progressCallbackId);
      }
    }
  }

  @override
  Future<ModelManifest> downloadModel({
    required String model,
    required String quantization,
    String? url,
    LeapDownloaderConfig? config,
    void Function(double progress, int bytesPerSecond)? onProgress,
  }) async {
    String? progressCallbackId;
    if (onProgress != null) {
      progressCallbackId = _generateCallbackId();
      _progressCallbacks[progressCallbackId] = onProgress;
    }

    try {
      final result = await methodChannel.invokeMethod<Map>('downloadModel', {
        'model': model,
        'quantization': quantization,
        if (url != null) 'url': url,
        if (config?.saveDirectory != null)
          'saveDirectory': config!.saveDirectory,
        if (progressCallbackId != null)
          'progressCallbackId': progressCallbackId,
      });

      return ModelManifest(
        modelSlug: result!['modelSlug'] as String? ?? model,
        quantizationSlug: result['quantizationSlug'] as String? ?? quantization,
        schemaVersion: result['schemaVersion'] as String? ?? '1.0',
        inferenceType: result['inferenceType'] as String? ?? 'unknown',
        localModelPath: result['localModelPath'] as String? ??
            result['modelPath'] as String? ??
            '',
      );
    } finally {
      if (progressCallbackId != null) {
        _progressCallbacks.remove(progressCallbackId);
      }
    }
  }

  @override
  Future<bool> isModelCached({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('isModelCached', {
      'model': model,
      'quantization': quantization,
      if (config?.saveDirectory != null) 'saveDirectory': config!.saveDirectory,
    });
    return result ?? false;
  }

  @override
  Future<bool> deleteModel({
    required String model,
    required String quantization,
    LeapDownloaderConfig? config,
  }) async {
    final result = await methodChannel.invokeMethod<bool>('deleteModel', {
      'model': model,
      'quantization': quantization,
      if (config?.saveDirectory != null) 'saveDirectory': config!.saveDirectory,
    });
    return result ?? false;
  }

  // MARK: - Parsing Helpers

  ChatMessage _parseChatMessage(Map data) {
    final roleStr = data['role'] as String;
    final role = ChatMessageRole.values.firstWhere((r) => r.name == roleStr);
    final contentList = (data['content'] as List).cast<Map>();
    final content = contentList.map(_parseChatMessageContent).toList();
    return ChatMessage(role: role, content: content);
  }

  ChatMessageContent _parseChatMessageContent(Map data) {
    return ChatMessageContent.fromJson(Map<String, dynamic>.from(data));
  }

  LeapFunctionCall _parseFunctionCall(Map data) {
    return LeapFunctionCall(
      name: data['name'] as String,
      arguments: Map<String, dynamic>.from(data['arguments'] as Map),
    );
  }

  GenerationStats? _parseStats(Map? data) {
    if (data == null) return null;
    return GenerationStats(
      promptTokens: data['promptTokens'] as int,
      completionTokens: data['completionTokens'] as int,
      totalTokens: data['totalTokens'] as int,
      tokensPerSecond: data['tokensPerSecond'] as double,
    );
  }
}

/// A ModelRunner implementation that uses method channels.
class _MethodChannelModelRunner extends ModelRunner {
  _MethodChannelModelRunner({
    required this.runnerId,
    required this.channel,
    required this.streamControllers,
    required this.generateCallbackId,
  });

  final String runnerId;
  final MethodChannel channel;
  final Map<String, StreamController<MessageResponse>> streamControllers;
  final String Function() generateCallbackId;

  @override
  Future<Conversation> createConversation({
    String? systemPrompt,
  }) async {
    final result = await channel.invokeMethod<Map>('createConversation', {
      'runnerId': runnerId,
      if (systemPrompt != null) 'systemPrompt': systemPrompt,
    });
    return _MethodChannelConversation(
      conversationId: result!['conversationId'] as String,
      channel: channel,
      streamControllers: streamControllers,
      generateCallbackId: generateCallbackId,
    );
  }

  @override
  Future<Conversation> createConversationFromHistory(
    List<ChatMessage> history,
  ) async {
    final result = await channel.invokeMethod<Map>(
      'createConversationFromHistory',
      {
        'runnerId': runnerId,
        'history': history.map((m) => m.toJson()).toList(),
      },
    );
    return _MethodChannelConversation(
      conversationId: result!['conversationId'] as String,
      channel: channel,
      streamControllers: streamControllers,
      generateCallbackId: generateCallbackId,
    );
  }

  @override
  Future<void> unload() async {
    await channel.invokeMethod('unloadModel', {'runnerId': runnerId});
  }
}

/// A Conversation implementation that uses method channels.
class _MethodChannelConversation extends Conversation {
  _MethodChannelConversation({
    required this.conversationId,
    required this.channel,
    required this.streamControllers,
    required this.generateCallbackId,
  });

  final String conversationId;
  final MethodChannel channel;
  final Map<String, StreamController<MessageResponse>> streamControllers;
  final String Function() generateCallbackId;

  @override
  Stream<MessageResponse> generateResponse({
    required ChatMessage message,
    GenerationOptions? options,
  }) {
    final callbackId = generateCallbackId();
    final controller = StreamController<MessageResponse>();
    streamControllers[callbackId] = controller;

    // Start generation
    channel.invokeMethod('generateResponse', {
      'conversationId': conversationId,
      'message': message.toJson(),
      'streamCallbackId': callbackId,
      if (options != null) 'options': _serializeGenerationOptions(options),
    }).catchError((error) {
      controller.addError(error);
      controller.close();
      streamControllers.remove(callbackId);
    });

    return controller.stream;
  }

  @override
  Future<void> registerFunction(LeapFunction function) async {
    await channel.invokeMethod('registerFunction', {
      'conversationId': conversationId,
      'function': _serializeFunction(function),
    });
  }

  @override
  List<ChatMessage> get history => [];

  @override
  Future<void> dispose() async {
    await channel.invokeMethod('disposeConversation', {
      'conversationId': conversationId,
    });
  }

  Map<String, dynamic> _serializeGenerationOptions(GenerationOptions options) {
    return {
      if (options.temperature != null) 'temperature': options.temperature,
      if (options.topP != null) 'topP': options.topP,
      if (options.minP != null) 'minP': options.minP,
      if (options.repetitionPenalty != null)
        'repetitionPenalty': options.repetitionPenalty,
      if (options.jsonSchemaConstraint != null)
        'jsonSchemaConstraint': options.jsonSchemaConstraint,
      if (options.maxTokens != null) 'maxTokens': options.maxTokens,
    };
  }

  Map<String, dynamic> _serializeFunction(LeapFunction function) {
    return {
      'name': function.name,
      'description': function.description,
      'parameters': function.parameters.map((p) => p.toJson()).toList(),
    };
  }
}
