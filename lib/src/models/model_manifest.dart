/// Metadata about a downloaded model.
///
/// Contains information about the model manifest including paths,
/// configuration, and generation parameters.
class ModelManifest {
  /// Creates a new [ModelManifest].
  const ModelManifest({
    required this.modelSlug,
    required this.quantizationSlug,
    required this.schemaVersion,
    required this.inferenceType,
    required this.localModelPath,
    this.multimodalProjectorPath,
    this.audioDecoderPath,
    this.audioTokenizerPath,
    this.chatTemplate,
  });

  /// The model slug identifier (e.g., 'LFM2-1.2B').
  final String modelSlug;

  /// The quantization level (e.g., 'Q5_K_M').
  final String quantizationSlug;

  /// The schema version of the manifest.
  final String schemaVersion;

  /// The inference type (e.g., 'gguf', 'executorch').
  final String inferenceType;

  /// Path to the local model file.
  final String localModelPath;

  /// Optional path to the multimodal projector for vision models.
  final String? multimodalProjectorPath;

  /// Optional path to the audio decoder for audio models.
  final String? audioDecoderPath;

  /// Optional path to the audio tokenizer for audio models.
  final String? audioTokenizerPath;

  /// Optional chat template for the model.
  final String? chatTemplate;

  /// Whether this model supports vision input.
  bool get supportsVision => multimodalProjectorPath != null;

  /// Whether this model supports audio input.
  bool get supportsAudio => audioDecoderPath != null;

  /// Converts this manifest to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'model_slug': modelSlug,
      'quantization_slug': quantizationSlug,
      'schema_version': schemaVersion,
      'inference_type': inferenceType,
      'local_model_path': localModelPath,
      if (multimodalProjectorPath != null)
        'multimodal_projector_path': multimodalProjectorPath,
      if (audioDecoderPath != null) 'audio_decoder_path': audioDecoderPath,
      if (audioTokenizerPath != null)
        'audio_tokenizer_path': audioTokenizerPath,
      if (chatTemplate != null) 'chat_template': chatTemplate,
    };
  }

  /// Creates a [ModelManifest] from a JSON map.
  factory ModelManifest.fromJson(Map<String, dynamic> json) {
    return ModelManifest(
      modelSlug: json['model_slug'] as String,
      quantizationSlug: json['quantization_slug'] as String,
      schemaVersion: json['schema_version'] as String,
      inferenceType: json['inference_type'] as String,
      localModelPath: json['local_model_path'] as String,
      multimodalProjectorPath: json['multimodal_projector_path'] as String?,
      audioDecoderPath: json['audio_decoder_path'] as String?,
      audioTokenizerPath: json['audio_tokenizer_path'] as String?,
      chatTemplate: json['chat_template'] as String?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ModelManifest) return false;
    return modelSlug == other.modelSlug &&
        quantizationSlug == other.quantizationSlug &&
        localModelPath == other.localModelPath;
  }

  @override
  int get hashCode => Object.hash(modelSlug, quantizationSlug, localModelPath);

  @override
  String toString() => 'ModelManifest($modelSlug, $quantizationSlug)';
}
