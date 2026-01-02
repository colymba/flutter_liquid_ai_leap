/// Represents the data type of a function parameter.
///
/// These types map to JSON Schema types and are used by the model to
/// understand what values are valid for function parameters.
///
/// ## Example
///
/// ```dart
/// // Simple types
/// final stringType = LeapFunctionParameterType.string();
/// final numberType = LeapFunctionParameterType.number();
/// final boolType = LeapFunctionParameterType.boolean();
///
/// // Enum-constrained string
/// final unitType = LeapFunctionParameterType.string(
///   enumValues: ['celsius', 'fahrenheit', 'kelvin'],
/// );
///
/// // Array of strings
/// final citiesType = LeapFunctionParameterType.array(
///   itemType: LeapFunctionParameterType.string(),
/// );
///
/// // Complex object
/// final locationObject = LeapFunctionParameterType.object(
///   properties: {
///     'latitude': LeapFunctionParameterType.number(),
///     'longitude': LeapFunctionParameterType.number(),
///   },
///   required: ['latitude', 'longitude'],
/// );
/// ```
sealed class LeapFunctionParameterType {
  /// Creates a new [LeapFunctionParameterType].
  const LeapFunctionParameterType({this.description});

  /// Optional description for this type.
  final String? description;

  /// Creates a string type parameter.
  ///
  /// [enumValues] restricts valid values to the given list.
  /// [description] provides additional context for the type.
  factory LeapFunctionParameterType.string({
    List<String>? enumValues,
    String? description,
  }) = StringParameterType;

  /// Creates a number type parameter (integer or floating point).
  ///
  /// [enumValues] restricts valid values to the given list.
  /// [description] provides additional context for the type.
  factory LeapFunctionParameterType.number({
    List<num>? enumValues,
    String? description,
  }) = NumberParameterType;

  /// Creates an integer type parameter.
  ///
  /// [enumValues] restricts valid values to the given list.
  /// [description] provides additional context for the type.
  factory LeapFunctionParameterType.integer({
    List<int>? enumValues,
    String? description,
  }) = IntegerParameterType;

  /// Creates a boolean type parameter.
  ///
  /// [description] provides additional context for the type.
  factory LeapFunctionParameterType.boolean({
    String? description,
  }) = BooleanParameterType;

  /// Creates an array type parameter.
  ///
  /// [itemType] defines the type of items in the array.
  /// [description] provides additional context for the type.
  factory LeapFunctionParameterType.array({
    required LeapFunctionParameterType itemType,
    String? description,
  }) = ArrayParameterType;

  /// Creates an object type parameter.
  ///
  /// [properties] maps property names to their types.
  /// [required] lists the names of required properties.
  /// [description] provides additional context for the type.
  factory LeapFunctionParameterType.object({
    required Map<String, LeapFunctionParameterType> properties,
    List<String> required,
    String? description,
  }) = ObjectParameterType;

  /// Creates a null type parameter.
  factory LeapFunctionParameterType.nullType() = NullParameterType;

  /// Converts this type to a JSON Schema representation.
  Map<String, dynamic> toJson();

  /// Creates a [LeapFunctionParameterType] from a JSON Schema map.
  factory LeapFunctionParameterType.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    final description = json['description'] as String?;

    switch (type) {
      case 'string':
        return StringParameterType(
          enumValues: (json['enum'] as List?)?.cast<String>(),
          description: description,
        );
      case 'number':
        return NumberParameterType(
          enumValues: (json['enum'] as List?)?.cast<num>(),
          description: description,
        );
      case 'integer':
        return IntegerParameterType(
          enumValues: (json['enum'] as List?)?.cast<int>(),
          description: description,
        );
      case 'boolean':
        return BooleanParameterType(description: description);
      case 'array':
        return ArrayParameterType(
          itemType: LeapFunctionParameterType.fromJson(
            json['items'] as Map<String, dynamic>,
          ),
          description: description,
        );
      case 'object':
        final properties = json['properties'] as Map<String, dynamic>?;
        final required = (json['required'] as List?)?.cast<String>() ?? [];
        return ObjectParameterType(
          properties: properties?.map(
                (key, value) => MapEntry(
                  key,
                  LeapFunctionParameterType.fromJson(
                      value as Map<String, dynamic>),
                ),
              ) ??
              {},
          required: required,
          description: description,
        );
      case 'null':
        return const NullParameterType();
      default:
        throw FormatException('Unknown parameter type: $type');
    }
  }
}

/// A string parameter type.
class StringParameterType extends LeapFunctionParameterType {
  /// Creates a string parameter type.
  const StringParameterType({
    this.enumValues,
    super.description,
  });

  /// Optional list of allowed values.
  final List<String>? enumValues;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'string',
      if (enumValues != null) 'enum': enumValues,
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StringParameterType) return false;
    return _listEquals(enumValues, other.enumValues) &&
        description == other.description;
  }

  @override
  int get hashCode => Object.hash(enumValues, description);
}

/// A number parameter type (integer or floating point).
class NumberParameterType extends LeapFunctionParameterType {
  /// Creates a number parameter type.
  const NumberParameterType({
    this.enumValues,
    super.description,
  });

  /// Optional list of allowed values.
  final List<num>? enumValues;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'number',
      if (enumValues != null) 'enum': enumValues,
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! NumberParameterType) return false;
    return _listEquals(enumValues, other.enumValues) &&
        description == other.description;
  }

  @override
  int get hashCode => Object.hash(enumValues, description);
}

/// An integer parameter type.
class IntegerParameterType extends LeapFunctionParameterType {
  /// Creates an integer parameter type.
  const IntegerParameterType({
    this.enumValues,
    super.description,
  });

  /// Optional list of allowed values.
  final List<int>? enumValues;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'integer',
      if (enumValues != null) 'enum': enumValues,
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! IntegerParameterType) return false;
    return _listEquals(enumValues, other.enumValues) &&
        description == other.description;
  }

  @override
  int get hashCode => Object.hash(enumValues, description);
}

/// A boolean parameter type.
class BooleanParameterType extends LeapFunctionParameterType {
  /// Creates a boolean parameter type.
  const BooleanParameterType({super.description});

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'boolean',
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BooleanParameterType) return false;
    return description == other.description;
  }

  @override
  int get hashCode => description.hashCode;
}

/// An array parameter type.
class ArrayParameterType extends LeapFunctionParameterType {
  /// Creates an array parameter type.
  const ArrayParameterType({
    required this.itemType,
    super.description,
  });

  /// The type of items in the array.
  final LeapFunctionParameterType itemType;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'array',
      'items': itemType.toJson(),
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ArrayParameterType) return false;
    return itemType == other.itemType && description == other.description;
  }

  @override
  int get hashCode => Object.hash(itemType, description);
}

/// An object parameter type.
class ObjectParameterType extends LeapFunctionParameterType {
  /// Creates an object parameter type.
  const ObjectParameterType({
    required this.properties,
    this.required = const [],
    super.description,
  });

  /// Map of property names to their types.
  final Map<String, LeapFunctionParameterType> properties;

  /// List of required property names.
  final List<String> required;

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'object',
      'properties':
          properties.map((key, value) => MapEntry(key, value.toJson())),
      if (required.isNotEmpty) 'required': required,
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ObjectParameterType) return false;
    return _mapEquals(properties, other.properties) &&
        _listEquals(required, other.required) &&
        description == other.description;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(properties.entries),
        Object.hashAll(required),
        description,
      );
}

/// A null parameter type.
class NullParameterType extends LeapFunctionParameterType {
  /// Creates a null parameter type.
  const NullParameterType() : super(description: null);

  @override
  Map<String, dynamic> toJson() {
    return {'type': 'null'};
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NullParameterType;
  }

  @override
  int get hashCode => 'null'.hashCode;
}

bool _listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key)) return false;
    if (a[key] != b[key]) return false;
  }
  return true;
}
