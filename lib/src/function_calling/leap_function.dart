import 'leap_function_parameter.dart';
import 'leap_function_parameter_type.dart';

/// Defines a function that can be called by the model.
///
/// Register functions with a conversation to allow the model to request
/// function calls during generation. The model will generate function call
/// requests when it determines a function would be helpful.
///
/// ## Example
///
/// ```dart
/// final weatherFunction = LeapFunction(
///   name: 'get_weather',
///   description: 'Get the weather forecast for a city',
///   parameters: [
///     LeapFunctionParameter(
///       name: 'city',
///       type: LeapFunctionParameterType.string(),
///       description: 'The city to get weather for',
///     ),
///     LeapFunctionParameter(
///       name: 'unit',
///       type: LeapFunctionParameterType.string(
///         enumValues: ['celsius', 'fahrenheit'],
///       ),
///       description: 'Temperature unit',
///       optional: true,
///     ),
///   ],
/// );
///
/// conversation.registerFunction(weatherFunction);
/// ```
class LeapFunction {
  /// Creates a new [LeapFunction].
  ///
  /// [name] is the function name (use letters, underscores, and digits).
  /// [description] explains what the function does for the model.
  /// [parameters] defines the function's parameters.
  const LeapFunction({
    required this.name,
    required this.description,
    this.parameters = const [],
  });

  /// The name of the function.
  ///
  /// Should use only English letters, underscores, and digits (not starting
  /// with digits) for maximum compatibility across models.
  final String name;

  /// A human and LLM readable description of what this function does.
  ///
  /// Be descriptive to help the model understand when to use this function.
  final String description;

  /// The list of parameters this function accepts.
  ///
  /// Order matters - parameters are declared in order.
  final List<LeapFunctionParameter> parameters;

  /// Converts this function definition to a JSON-serializable map.
  ///
  /// The format is compatible with JSON Schema and the OpenAI function
  /// calling format.
  Map<String, dynamic> toJson() {
    final requiredParams =
        parameters.where((p) => !p.optional).map((p) => p.name).toList();

    final properties = <String, dynamic>{};
    for (final param in parameters) {
      properties[param.name] = param.type.toJson();
      // Add description at the property level
      if (param.description.isNotEmpty) {
        (properties[param.name] as Map<String, dynamic>)['description'] =
            param.description;
      }
    }

    return {
      'name': name,
      'description': description,
      'parameters': {
        'type': 'object',
        'properties': properties,
        if (requiredParams.isNotEmpty) 'required': requiredParams,
      },
    };
  }

  /// Creates a [LeapFunction] from a JSON map.
  factory LeapFunction.fromJson(Map<String, dynamic> json) {
    final parametersJson = json['parameters'] as Map<String, dynamic>?;
    final properties =
        parametersJson?['properties'] as Map<String, dynamic>? ?? {};
    final required =
        (parametersJson?['required'] as List?)?.cast<String>() ?? [];

    final parameters = properties.entries.map((entry) {
      return LeapFunctionParameter(
        name: entry.key,
        type: LeapFunctionParameterType.fromJson(
            entry.value as Map<String, dynamic>),
        description:
            (entry.value as Map<String, dynamic>)['description'] as String? ??
                '',
        optional: !required.contains(entry.key),
      );
    }).toList();

    return LeapFunction(
      name: json['name'] as String,
      description: json['description'] as String,
      parameters: parameters,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LeapFunction) return false;
    return name == other.name &&
        description == other.description &&
        _listEquals(parameters, other.parameters);
  }

  @override
  int get hashCode =>
      Object.hash(name, description, Object.hashAll(parameters));

  @override
  String toString() =>
      'LeapFunction(name: $name, parameters: ${parameters.length})';

  static bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
