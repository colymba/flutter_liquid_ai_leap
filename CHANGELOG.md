# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.3] - 2026-01-08

### Changed
- Fixed unclosed URLConnection in model downloader

### Added
- Now supports downloading and using split vision models (language + projector files)


## [0.2.2] - 2026-01-04

### Changed
- FIX: Pass images as bytes. Image inference will now work.


## [0.2.1] - 2026-01-04

### Changed
- Version bump


## [0.2.0] - 2026-01-04

### Changed
- Version bump

### Added
- FIX `ModelRunner.unload()` missing public API
- Document `downloadModel()`
- Docuemnt GGUF and tested models


## [Unreleased]

## [0.1.0] - 2025-01-XX

### Added

- Initial release of the Liquid AI LEAP Flutter plugin
- Core model loading and management
  - `LiquidAiLeap.loadModel()` - Download and load models
  - `LiquidAiLeap.downloadModel()` - Download models without loading
  - `LiquidAiLeap.isModelCached()` - Check cache status
  - `LiquidAiLeap.deleteModel()` - Remove cached models
- Conversation management
  - `ModelRunner.createConversation()` - Create new conversations
  - `ModelRunner.createConversationFromHistory()` - Restore from history
  - `Conversation.generateResponse()` - Streaming text generation
- Message types
  - `ChatMessage` - User, assistant, system, and tool messages
  - `ChatMessageContent` - Text, image, and audio content types
- Response types
  - `ChunkResponse` - Streaming text chunks
  - `ReasoningChunkResponse` - Reasoning model thinking
  - `AudioSampleResponse` - Audio output samples
  - `FunctionCallResponse` - Function call requests
  - `CompleteResponse` - Generation completion with stats
- Generation options
  - Temperature control
  - Top-P and Min-P sampling
  - Repetition penalty
  - Max tokens limit
  - JSON schema constraints
- Function calling support
  - `LeapFunction` - Function definitions
  - `LeapFunctionParameter` - Parameter specifications
  - `LeapFunctionParameterType` - Type system (string, number, etc.)
- Exception hierarchy
  - `LeapException` - Base exception type
  - `LeapNetworkException` - Network errors
  - `LeapModelNotFoundException` - Model not found
  - `LeapInsufficientMemoryException` - Memory errors
  - `LeapGenerationException` - Generation failures
- Platform implementations
  - iOS via Swift Package Manager
  - Android via Maven
- Utility scripts
  - `dependencies.sh` - Manage native SDK dependencies
  - `publish.sh` - Automated publishing workflow

### Platform Requirements

- iOS: 15.0+, Xcode 15.0+, Swift 5.9+
- Android: API 31+ (Android 12), arm64-v8a

### Known Issues

- Native SDK integration is scaffolded but requires LeapSDK availability
- iOS simulator support may be limited

[Unreleased]: https://github.com/user/liquid_ai_leap/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/user/liquid_ai_leap/releases/tag/v0.1.0
