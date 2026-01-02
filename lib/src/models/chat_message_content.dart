import 'dart:typed_data';

/// Represents the content of a chat message.
///
/// Chat messages can contain multiple content parts, including text, images,
/// and audio. This sealed class provides type-safe access to the different
/// content types.
///
/// ## Example
///
/// ```dart
/// // Create text content
/// final textContent = TextContent('Hello, world!');
///
/// // Create image content from JPEG bytes
/// final imageContent = ImageContent(jpegBytes);
///
/// // Create audio content from WAV bytes
/// final audioContent = AudioContent(wavBytes);
/// ```
sealed class ChatMessageContent {
  /// Creates a new [ChatMessageContent].
  const ChatMessageContent();

  /// Creates a text content part.
  ///
  /// [text] is the text content of the message.
  factory ChatMessageContent.text(String text) = TextContent;

  /// Creates an image content part from JPEG bytes.
  ///
  /// [jpegBytes] is the JPEG-encoded image data.
  factory ChatMessageContent.image(Uint8List jpegBytes) = ImageContent;

  /// Creates an audio content part from WAV bytes.
  ///
  /// [wavBytes] is the WAV-encoded audio data.
  factory ChatMessageContent.audio(Uint8List wavBytes) = AudioContent;

  /// Creates an audio content part from PCM float samples.
  ///
  /// [samples] is a list of PCM float samples.
  /// [sampleRate] is the sample rate in Hz (e.g., 16000 for 16kHz).
  factory ChatMessageContent.fromFloatSamples(
    List<double> samples, {
    required int sampleRate,
  }) = AudioContent.fromFloatSamples;

  /// Converts this content to a JSON-serializable map.
  ///
  /// The format is compatible with the OpenAI chat completion API.
  Map<String, dynamic> toJson();

  /// Creates a [ChatMessageContent] from a JSON map.
  ///
  /// The map should follow the OpenAI chat completion API format.
  ///
  /// Throws [FormatException] if the JSON format is invalid.
  factory ChatMessageContent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;

    switch (type) {
      case 'text':
        return TextContent(json['text'] as String);
      case 'image_url':
        final imageUrl = json['image_url'] as Map<String, dynamic>;
        final url = imageUrl['url'] as String;
        // Decode base64 data URL
        if (url.startsWith('data:image/jpeg;base64,')) {
          final base64Data = url.substring('data:image/jpeg;base64,'.length);
          return ImageContent(_decodeBase64(base64Data));
        }
        throw FormatException('Unsupported image URL format: $url');
      case 'input_audio':
        final audioData = json['input_audio'] as Map<String, dynamic>;
        final data = audioData['data'] as String;
        return AudioContent(_decodeBase64(data));
      default:
        throw FormatException('Unknown content type: $type');
    }
  }

  static Uint8List _decodeBase64(String base64) {
    // Remove any whitespace
    final cleanBase64 = base64.replaceAll(RegExp(r'\s'), '');
    // Dart's built-in base64 decoder
    return Uint8List.fromList(
      List<int>.from(
          Uri.parse('data:;base64,$cleanBase64').data!.contentAsBytes()),
    );
  }
}

/// Text content in a chat message.
///
/// Represents plain text content within a chat message.
class TextContent extends ChatMessageContent {
  /// Creates a new [TextContent] with the given [text].
  const TextContent(this.text);

  /// The text content.
  final String text;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'text',
      'text': text,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextContent && other.text == text;
  }

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'TextContent($text)';
}

/// Image content in a chat message.
///
/// Represents JPEG-encoded image data within a chat message.
/// Only models with vision capabilities can process image content.
class ImageContent extends ChatMessageContent {
  /// Creates a new [ImageContent] with the given JPEG bytes.
  const ImageContent(this.jpegBytes);

  /// The JPEG-encoded image data.
  final Uint8List jpegBytes;

  @override
  Map<String, dynamic> toJson() {
    final base64Data = _encodeBase64(jpegBytes);
    return {
      'type': 'image_url',
      'image_url': {
        'url': 'data:image/jpeg;base64,$base64Data',
      },
    };
  }

  static String _encodeBase64(Uint8List bytes) {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    final buffer = StringBuffer();
    final len = bytes.length;

    for (var i = 0; i < len; i += 3) {
      final b0 = bytes[i];
      final b1 = i + 1 < len ? bytes[i + 1] : 0;
      final b2 = i + 2 < len ? bytes[i + 2] : 0;

      buffer.write(chars[(b0 >> 2) & 0x3F]);
      buffer.write(chars[((b0 << 4) | (b1 >> 4)) & 0x3F]);
      buffer.write(i + 1 < len ? chars[((b1 << 2) | (b2 >> 6)) & 0x3F] : '=');
      buffer.write(i + 2 < len ? chars[b2 & 0x3F] : '=');
    }

    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ImageContent) return false;
    if (jpegBytes.length != other.jpegBytes.length) return false;
    for (var i = 0; i < jpegBytes.length; i++) {
      if (jpegBytes[i] != other.jpegBytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(jpegBytes);

  @override
  String toString() => 'ImageContent(${jpegBytes.length} bytes)';
}

/// Audio content in a chat message.
///
/// Represents WAV-encoded audio data within a chat message.
/// Only models with audio capabilities can process audio content.
class AudioContent extends ChatMessageContent {
  /// Creates a new [AudioContent] with the given WAV bytes.
  const AudioContent(this.wavBytes);

  /// Creates audio content from PCM float samples.
  ///
  /// [samples] is a list of PCM float samples in the range [-1.0, 1.0].
  /// [sampleRate] is the sample rate in Hz.
  factory AudioContent.fromFloatSamples(
    List<double> samples, {
    required int sampleRate,
  }) {
    // Create a simple WAV header and convert float samples to 16-bit PCM
    final numSamples = samples.length;
    final dataSize = numSamples * 2; // 16-bit = 2 bytes per sample
    final fileSize = 44 + dataSize; // WAV header is 44 bytes

    final buffer = ByteData(fileSize);

    // RIFF header
    buffer.setUint8(0, 0x52); // 'R'
    buffer.setUint8(1, 0x49); // 'I'
    buffer.setUint8(2, 0x46); // 'F'
    buffer.setUint8(3, 0x46); // 'F'
    buffer.setUint32(4, fileSize - 8, Endian.little);
    buffer.setUint8(8, 0x57); // 'W'
    buffer.setUint8(9, 0x41); // 'A'
    buffer.setUint8(10, 0x56); // 'V'
    buffer.setUint8(11, 0x45); // 'E'

    // fmt chunk
    buffer.setUint8(12, 0x66); // 'f'
    buffer.setUint8(13, 0x6D); // 'm'
    buffer.setUint8(14, 0x74); // 't'
    buffer.setUint8(15, 0x20); // ' '
    buffer.setUint32(16, 16, Endian.little); // Chunk size
    buffer.setUint16(20, 1, Endian.little); // Audio format (PCM)
    buffer.setUint16(22, 1, Endian.little); // Num channels (mono)
    buffer.setUint32(24, sampleRate, Endian.little); // Sample rate
    buffer.setUint32(28, sampleRate * 2, Endian.little); // Byte rate
    buffer.setUint16(32, 2, Endian.little); // Block align
    buffer.setUint16(34, 16, Endian.little); // Bits per sample

    // data chunk
    buffer.setUint8(36, 0x64); // 'd'
    buffer.setUint8(37, 0x61); // 'a'
    buffer.setUint8(38, 0x74); // 't'
    buffer.setUint8(39, 0x61); // 'a'
    buffer.setUint32(40, dataSize, Endian.little);

    // Convert float samples to 16-bit PCM
    for (var i = 0; i < numSamples; i++) {
      final sample = (samples[i] * 32767).clamp(-32768, 32767).toInt();
      buffer.setInt16(44 + i * 2, sample, Endian.little);
    }

    return AudioContent(buffer.buffer.asUint8List());
  }

  /// The WAV-encoded audio data.
  final Uint8List wavBytes;

  @override
  Map<String, dynamic> toJson() {
    final base64Data = ImageContent._encodeBase64(wavBytes);
    return {
      'type': 'input_audio',
      'input_audio': {
        'data': base64Data,
        'format': 'wav',
      },
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AudioContent) return false;
    if (wavBytes.length != other.wavBytes.length) return false;
    for (var i = 0; i < wavBytes.length; i++) {
      if (wavBytes[i] != other.wavBytes[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(wavBytes);

  @override
  String toString() => 'AudioContent(${wavBytes.length} bytes)';
}
