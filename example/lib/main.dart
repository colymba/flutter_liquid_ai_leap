import 'package:flutter/material.dart';
import 'dart:async';

import 'package:liquid_ai_leap/liquid_ai_leap.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Liquid AI LEAP Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final LiquidAiLeap _leap = LiquidAiLeap();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatEntry> _messages = [];

  ModelRunner? _modelRunner;
  Conversation? _conversation;

  bool _isLoading = false;
  bool _isGenerating = false;
  double _downloadProgress = 0;
  String _statusMessage = 'Not loaded';

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadModel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading model...';
      _downloadProgress = 0;
    });

    try {
      final runner = await _leap.loadModel(
        model: 'LFM2-1.2B',
        quantization: 'Q5_K_M',
        onProgress: (progress, bytesPerSecond) {
          setState(() {
            _downloadProgress = progress;
            final mbps = bytesPerSecond / (1024 * 1024);
            _statusMessage =
                'Downloading: ${(progress * 100).toStringAsFixed(1)}% (${mbps.toStringAsFixed(1)} MB/s)';
          });
        },
      );

      _modelRunner = runner;
      _conversation = await runner.createConversation(
        systemPrompt:
            'You are a helpful AI assistant. Be concise and friendly.',
      );

      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _conversation == null || _isGenerating) return;

    _messageController.clear();

    setState(() {
      _messages.add(_ChatEntry(role: 'user', content: text));
      _messages.add(_ChatEntry(role: 'assistant', content: ''));
      _isGenerating = true;
    });

    _scrollToBottom();

    try {
      final message = ChatMessage.user(text);
      final buffer = StringBuffer();

      await for (final response in _conversation!.generateResponse(
        message: message,
        options: const GenerationOptions(
          temperature: 0.7,
          maxTokens: 512,
        ),
      )) {
        switch (response) {
          case ChunkResponse(:final text):
            buffer.write(text);
            setState(() {
              _messages.last = _ChatEntry(
                role: 'assistant',
                content: buffer.toString(),
              );
            });
            _scrollToBottom();

          case ReasoningChunkResponse(:final reasoning):
            // Handle reasoning chunks if needed
            buffer.write(reasoning);

          case AudioSampleResponse():
            // Audio responses not handled in this example
            break;

          case FunctionCallResponse():
            // Function calls not handled in this example
            break;

          case CompleteResponse(:final stats):
            if (stats != null) {
              setState(() {
                _statusMessage =
                    '${stats.tokensPerSecond.toStringAsFixed(1)} tok/s';
              });
            }
        }
      }
    } catch (e) {
      setState(() {
        _messages.last = _ChatEntry(
          role: 'assistant',
          content: 'Error: $e',
        );
      });
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liquid AI LEAP'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (_modelRunner == null)
            TextButton.icon(
              onPressed: _isLoading ? null : _loadModel,
              icon: const Icon(Icons.download),
              label: const Text('Load Model'),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: Text(
                  _statusMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Loading progress
          if (_isLoading) LinearProgressIndicator(value: _downloadProgress),

          // Status bar when not loaded
          if (_modelRunner == null && !_isLoading)
            Container(
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                        'Tap "Load Model" to download and initialize the AI model.'),
                  ),
                ],
              ),
            ),

          // Messages list
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return _MessageBubble(
                  message: message,
                  isGenerating: _isGenerating && index == _messages.length - 1,
                );
              },
            ),
          ),

          // Input area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _modelRunner == null
                            ? 'Load model first...'
                            : 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      enabled: _modelRunner != null && !_isGenerating,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _modelRunner != null && !_isGenerating
                        ? _sendMessage
                        : null,
                    icon: _isGenerating
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatEntry {
  final String role;
  final String content;

  _ChatEntry({required this.role, required this.content});
}

class _MessageBubble extends StatelessWidget {
  final _ChatEntry message;
  final bool isGenerating;

  const _MessageBubble({
    required this.message,
    this.isGenerating = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content.isEmpty && isGenerating ? '...' : message.content,
              style: TextStyle(
                color: isUser
                    ? Theme.of(context).colorScheme.onPrimary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            if (isGenerating && !isUser)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
