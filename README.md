# Liquid AI LEAP Flutter Plugin

A Flutter plugin for on-device AI inference using [Liquid AI's LEAP SDK](https://liquid.ai/leap). Run Liquid Foundation Models (LFM) directly on iOS and Android devices with no cloud dependencies.

[![pub package](https://img.shields.io/pub/v/liquid_ai_leap.svg)](https://pub.dev/packages/liquid_ai_leap)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Why this plugin?

This supports **GGUF models**! Compared to LiteRT or ONNX GenAI, this give access to a much larger range of models.

## Features

- 🚀 **On-device inference** - Run AI models locally without internet
- 💬 **Streaming responses** - Real-time token-by-token output
- 🖼️ **Multimodal support** - Text, images, and audio inputs
- 🔧 **Function calling** - Let models call your app's functions
- 📝 **Constrained generation** - JSON schema validation for structured output
- 📦 **Automatic model management** - Download, cache, and manage models

## Supported Models

The plugin supports models from LiquidAI but also any GGUF model!

### Liquid AI Models

**LFM2-** Multimodal Models from liquid AI LEAP.
- Leap Library: [LFM2-1.2B](https://leap.liquid.ai/models)
- Leap Bundles: [Hugging Face: LiquidAI/LeapBundles](https://huggingface.co/LiquidAI/LeapBundles/tree/main)
- Liquid AI Models: [Hugging Face: LiquidAI/models](https://huggingface.co/LiquidAI/models)

### GGUF Models

More about [GGUF](https://huggingface.co/docs/hub/en/gguf).
- Find GGUF models on [Hugging Face](https://huggingface.co/models?library=gguf).

**Note:** The SDK now [recommends using GGUF](https://docs.liquid.ai/leap/edge-sdk/android/android-quick-start-guide#3-getting-and-loading-models) models instead of ExecuTorch bundles.

#### Tested models

These models have been successfully tested for on-device inference using the plugin.

| Model | Parameters | Quantizations | Capabilities |
|-------|------------|---------------|--------------|
| **LFM2-VL-1.6B** | 1.6B | Q8_0 (bundle) | Text, Vision |
| **LFM2-VL-3B** | 3B | Q8_0 (bundle) | Text, Vision |
| **LFM2-VL-3B-GGUF** | 3B | Q4_0 | Text, Vision |
| **Qwen3-VL-2B** | 2B | Q4_K_M | Text, Vision |
| **GLM-Edge-V-2B** | 1.6B | Q4_K_M | Text, Vision |
| **Qwen2-VL-2B** | 2B | Q5, Q4 | Text, Vision |
| **InternVL3-2B** | 1.8B | Q4_K_M | Text, Vision |
| **Omni-Reasoner-2B** | 1.5B | Q4_0 | Text, Vision |
| **Granite-Vision-3.2-2B** | 2.5B | Q4_K_M | Text, Vision |

## Requirements

### iOS
- iOS 15.0+
- Xcode 15.0+
- Swift 5.9+
- Physical device recommended (3GB+ RAM)

### Android
- API 31+ (Android 12)
- arm64-v8a ABI
- Physical device recommended (3GB+ RAM)

## Installation

Add this to your package's `pubspec.yaml`:

```yaml
dependencies:
  liquid_ai_leap: ^0.1.0
```

Then run:

```bash
flutter pub get
```

## Quick Start

### 1. Initialize and Load a Model

```dart
import 'package:liquid_ai_leap/liquid_ai_leap.dart';

// Create plugin instance
final leap = LiquidAiLeap();

// Load a model (downloads if not cached)
final modelRunner = await leap.loadModel(
  model: 'LFM2-1.2B',
  quantization: 'Q5_K_M',
  onProgress: (progress, bytesPerSecond) {
    print('Downloading: ${(progress * 100).toStringAsFixed(1)}%');
  },
);
```

**Note:** The `loadModel` will search Leap models library using `model` and `quantization` parameters. During testing this was found to be somewhat unrialiable. If you are having issues with the *auto-download* like me, use the `downloadModel` method to download the model first, then use the `loadModel` method to load the model. `downloadModel` uses the `url` parameter to download the model (*.bundle* or *.gguf*) from Hugging Face for example.

### 2. Create a Conversation

```dart
// Create a conversation with optional system prompt
final conversation = modelRunner.createConversation(
  systemPrompt: 'You are a helpful assistant.',
);
```

### 3. Generate Responses

```dart
// Send a message and stream the response
final message = ChatMessage.user('What is the capital of France?');

await for (final response in conversation.generateResponse(message: message)) {
  switch (response) {
    case ChunkResponse(:final text):
      // Print streamed text
      stdout.write(text);
    case CompleteResponse(:final message, :final stats):
      // Generation complete
      print('\n\nTokens: ${stats?.totalTokens}');
      print('Speed: ${stats?.tokensPerSecond.toStringAsFixed(1)} tok/s');
  }
}
```

## Advanced Usage

### Generation Options

Control generation behavior with `GenerationOptions`:

```dart
await for (final response in conversation.generateResponse(
  message: ChatMessage.user('Write a haiku about Flutter'),
  options: GenerationOptions(
    temperature: 0.7,      // Creativity (0.0-2.0)
    topP: 0.9,             // Nucleus sampling
    maxTokens: 100,        // Maximum tokens to generate
    repetitionPenalty: 1.1, // Reduce repetition
  ),
)) {
  // Handle response
}
```

### Function Calling

Register functions for the model to call:

```dart
// Define a function
final weatherFunction = LeapFunction(
  name: 'get_weather',
  description: 'Get the current weather for a location',
  parameters: [
    LeapFunctionParameter(
      name: 'city',
      type: LeapFunctionParameterType.string(),
      description: 'The city name',
    ),
    LeapFunctionParameter(
      name: 'units',
      type: LeapFunctionParameterType.string(
        enumValues: ['celsius', 'fahrenheit'],
      ),
      description: 'Temperature units',
      optional: true,
    ),
  ],
);

// Register the function
conversation.registerFunction(weatherFunction);

// Handle function calls in responses
await for (final response in conversation.generateResponse(
  message: ChatMessage.user('What is the weather in Paris?'),
)) {
  switch (response) {
    case FunctionCallResponse(:final calls):
      for (final call in calls) {
        final result = await handleFunctionCall(call);
        // Provide result back to model
      }
    case ChunkResponse(:final text):
      stdout.write(text);
  }
}
```

### Constrained JSON Generation

Force the model to output valid JSON matching a schema:

```dart
final response = await conversation.generateResponse(
  message: ChatMessage.user('Generate a user profile'),
  options: GenerationOptions(
    jsonSchemaConstraint: '''
    {
      "type": "object",
      "properties": {
        "name": { "type": "string" },
        "age": { "type": "integer" },
        "email": { "type": "string" }
      },
      "required": ["name", "email"]
    }
    ''',
  ),
);
```

### Image Input (Vision Models)

```dart
import 'dart:io';
import 'dart:typed_data';

// Load image bytes
final imageBytes = await File('photo.jpg').readAsBytes();

// Create message with image
final message = ChatMessage(
  role: ChatMessageRole.user,
  content: [
    ChatMessageContent.text('What do you see in this image?'),
    ChatMessageContent.image(imageBytes),
  ],
);

await for (final response in conversation.generateResponse(message: message)) {
  // Handle response
}
```

### Audio Input (Audio Models)

```dart
// Create message with audio
final message = ChatMessage(
  role: ChatMessageRole.user,
  content: [
    ChatMessageContent.text('Transcribe this audio:'),
    ChatMessageContent.audio(wavBytes),
  ],
);
```

### Model Management

```dart
// Check if a model is cached
final isCached = await leap.isModelCached(
  model: 'LFM2-1.2B',
  quantization: 'Q5_K_M',
);

// Download without loading
final manifest = await leap.downloadModel(
  model: 'LFM2-1.2B',
  quantization: 'Q5_K_M',
  url: 'https://huggingface.co/LiquidAI/LeapBundles/resolve/main/LFM2-1_2B_8da4w.bundle?download=true',
  onProgress: (progress, bytesPerSecond) {
    print('Downloading: ${(progress * 100).toStringAsFixed(1)}%');
  },
);

// Delete a cached model
await leap.deleteModel(
  model: 'LFM2-1.2B',
  quantization: 'Q5_K_M',
);
```

### Cleanup

```dart
// Unload model to free memory
await modelRunner.unload();
```

## Error Handling

```dart
import 'package:liquid_ai_leap/liquid_ai_leap.dart';

try {
  final runner = await leap.loadModel(...);
} on LeapNetworkException catch (e) {
  print('Network error: ${e.message}');
} on LeapModelNotFoundException catch (e) {
  print('Model not found: ${e.model}');
} on LeapInsufficientMemoryException catch (e) {
  print('Not enough memory to load model');
} on LeapException catch (e) {
  print('LEAP error: ${e.message}');
}
```

## Platform Setup

### iOS

The plugin uses Swift Package Manager to fetch the LEAP SDK. No additional setup required.

If you need to customize the build, update `ios/liquid_ai_leap.podspec`.

### Android

The plugin uses Maven to fetch the LEAP SDK. You may need to configure authentication for the Maven repository.

Add to your app's `android/build.gradle`:

```gradle
allprojects {
    repositories {
        maven {
            url 'https://maven.pkg.github.com/Liquid4All/leap-android'
            credentials {
                username = System.getenv('GITHUB_USERNAME')
                password = System.getenv('GITHUB_TOKEN')
            }
        }
    }
}
```

## Scripts

### Dependency Management

```bash
# Sync dependencies to pinned versions
./scripts/dependencies.sh sync

# Check for and upgrade to latest SDK versions
./scripts/dependencies.sh upgrade
```

### Publishing

```bash
# Publish a bug fix (0.1.0 -> 0.1.1)
./scripts/publish.sh fix

# Publish a new feature (0.1.0 -> 0.2.0)
./scripts/publish.sh minor

# Publish a breaking change (0.1.0 -> 1.0.0)
./scripts/publish.sh major
```

## API Reference

See the [API documentation](https://pub.dev/documentation/liquid_ai_leap/latest/) for detailed information.

## Contributing

Contributions are welcome!

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Liquid AI](https://liquid.ai) for the LEAP SDK
