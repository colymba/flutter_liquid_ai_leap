/// Options for controlling model generation behavior.
///
/// Use these options to tune the model's output characteristics such as
/// randomness, repetition, and structured output format.
///
/// ## Example
///
/// ```dart
/// // Create options with custom temperature
/// final options = GenerationOptions(
///   temperature: 0.7,
///   topP: 0.9,
/// );
///
/// // Generate with options
/// await for (final response in conversation.generateResponse(
///   message: ChatMessage.user('Write a poem'),
///   options: options,
/// )) {
///   // Handle response
/// }
/// ```
class GenerationOptions {
  /// Creates new [GenerationOptions].
  ///
  /// All parameters are optional. If not set, the model's default values
  /// from the manifest will be used.
  const GenerationOptions({
    this.temperature,
    this.topP,
    this.minP,
    this.repetitionPenalty,
    this.jsonSchemaConstraint,
    this.maxTokens,
    this.extras,
  });

  /// Sampling temperature parameter.
  ///
  /// Higher values (e.g., 0.8-1.0) make output more random.
  /// Lower values (e.g., 0.2-0.5) make output more focused and deterministic.
  /// Typically ranges from 0.0 to 2.0.
  final double? temperature;

  /// Nucleus sampling parameter.
  ///
  /// The model only considers tokens with cumulative probability up to [topP].
  /// A value of 0.9 means the model considers tokens comprising the top 90%
  /// of probability mass.
  final double? topP;

  /// Minimum probability for a token to be considered.
  ///
  /// Tokens with probability below this threshold are excluded from sampling.
  final double? minP;

  /// Repetition penalty parameter.
  ///
  /// A positive value decreases the likelihood of the model repeating
  /// the same text verbatim. Values > 1.0 penalize repetition.
  final double? repetitionPenalty;

  /// JSON schema constraint for structured output.
  ///
  /// When set, the model will generate output that conforms to the given
  /// JSON schema.
  final String? jsonSchemaConstraint;

  /// Maximum number of tokens to generate.
  ///
  /// If not set, the model will generate until it reaches a stop condition
  /// or the maximum context length.
  final int? maxTokens;

  /// Additional parameters passed directly to the model.
  ///
  /// This is a flexible map that can contain any additional parameters
  /// supported by the model, such as:
  /// - `max_tokens`: Maximum tokens (alternative to maxTokens)
  /// - `min_image_tokens`: Minimum image token count
  /// - `max_image_tokens`: Maximum image token count
  /// - `do_image_splitting`: Enable image splitting
  final Map<String, dynamic>? extras;

  /// Creates a copy of this options with the given fields replaced.
  GenerationOptions copyWith({
    double? temperature,
    double? topP,
    double? minP,
    double? repetitionPenalty,
    String? jsonSchemaConstraint,
    int? maxTokens,
    Map<String, dynamic>? extras,
  }) {
    return GenerationOptions(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      minP: minP ?? this.minP,
      repetitionPenalty: repetitionPenalty ?? this.repetitionPenalty,
      jsonSchemaConstraint: jsonSchemaConstraint ?? this.jsonSchemaConstraint,
      maxTokens: maxTokens ?? this.maxTokens,
      extras: extras ?? this.extras,
    );
  }

  /// Converts this options object to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      if (temperature != null) 'temperature': temperature,
      if (topP != null) 'top_p': topP,
      if (minP != null) 'min_p': minP,
      if (repetitionPenalty != null) 'repetition_penalty': repetitionPenalty,
      if (jsonSchemaConstraint != null)
        'json_schema_constraint': jsonSchemaConstraint,
      if (maxTokens != null) 'max_tokens': maxTokens,
      if (extras != null) 'extras': extras,
    };
  }

  /// Creates a [GenerationOptions] from a JSON map.
  factory GenerationOptions.fromJson(Map<String, dynamic> json) {
    return GenerationOptions(
      temperature: (json['temperature'] as num?)?.toDouble(),
      topP: (json['top_p'] as num?)?.toDouble(),
      minP: (json['min_p'] as num?)?.toDouble(),
      repetitionPenalty: (json['repetition_penalty'] as num?)?.toDouble(),
      jsonSchemaConstraint: json['json_schema_constraint'] as String?,
      maxTokens: json['max_tokens'] as int?,
      extras: json['extras'] as Map<String, dynamic>?,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! GenerationOptions) return false;
    return temperature == other.temperature &&
        topP == other.topP &&
        minP == other.minP &&
        repetitionPenalty == other.repetitionPenalty &&
        jsonSchemaConstraint == other.jsonSchemaConstraint &&
        maxTokens == other.maxTokens &&
        _mapEquals(extras, other.extras);
  }

  @override
  int get hashCode => Object.hash(
        temperature,
        topP,
        minP,
        repetitionPenalty,
        jsonSchemaConstraint,
        maxTokens,
        extras,
      );

  @override
  String toString() {
    final parts = <String>[];
    if (temperature != null) parts.add('temperature: $temperature');
    if (topP != null) parts.add('topP: $topP');
    if (minP != null) parts.add('minP: $minP');
    if (repetitionPenalty != null) {
      parts.add('repetitionPenalty: $repetitionPenalty');
    }
    if (maxTokens != null) parts.add('maxTokens: $maxTokens');
    if (jsonSchemaConstraint != null) parts.add('jsonSchema: [set]');
    if (extras != null) parts.add('extras: $extras');
    return 'GenerationOptions(${parts.join(', ')})';
  }

  // Helper for map equality
  static bool _mapEquals(Map? a, Map? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (var key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
