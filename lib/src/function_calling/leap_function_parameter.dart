import 'leap_function_parameter_type.dart';

/// Defines a parameter for a function that can be called by the model.
///
/// Parameters describe the expected inputs for a [LeapFunction].
///
/// ## Example
///
/// ```dart
/// final cityParam = LeapFunctionParameter(
///   name: 'city',
///   type: LeapFunctionParameterType.string(),
///   description: 'The city to get weather for',
/// );
///
/// final temperatureParam = LeapFunctionParameter(
///   name: 'temperature',
///   type: LeapFunctionParameterType.number(),
///   description: 'Temperature threshold',
///   optional: true,
/// );
/// ```
class LeapFunctionParameter {
  /// Creates a new [LeapFunctionParameter].
  ///
  /// [name] is the parameter name.
  /// [type] is the data type of the parameter.
  /// [description] explains what the parameter is for.
  /// [optional] indicates whether this parameter can be omitted.
  const LeapFunctionParameter({
    required this.name,
    required this.type,
    required this.description,
    this.optional = false,
  });

  /// The name of the parameter.
  final String name;

  /// The data type of the parameter.
  final LeapFunctionParameterType type;

  /// A description of what this parameter is for.
  ///
  /// This helps the model understand how to fill in the parameter.
  final String description;

  /// Whether this parameter is optional.
  ///
  /// Optional parameters may not be included in function call arguments.
  final bool optional;

  /// Converts this parameter to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.toJson(),
      'description': description,
      'optional': optional,
    };
  }

  /// Creates a [LeapFunctionParameter] from a JSON map.
  factory LeapFunctionParameter.fromJson(Map<String, dynamic> json) {
    return LeapFunctionParameter(
      name: json['name'] as String,
      type: LeapFunctionParameterType.fromJson(
          json['type'] as Map<String, dynamic>),
      description: json['description'] as String,
      optional: json['optional'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LeapFunctionParameter) return false;
    return name == other.name &&
        type == other.type &&
        description == other.description &&
        optional == other.optional;
  }

  @override
  int get hashCode => Object.hash(name, type, description, optional);

  @override
  String toString() => 'LeapFunctionParameter(name: $name, type: $type)';
}
