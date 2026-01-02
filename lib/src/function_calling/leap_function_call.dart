/// Represents a function call request from the model.
///
/// When the model decides to call a registered function, it generates a
/// [LeapFunctionCall] containing the function name and arguments.
///
/// ## Example
///
/// ```dart
/// // Handling function calls in a response stream
/// await for (final response in conversation.generateResponse(message: msg)) {
///   if (response is FunctionCallResponse) {
///     for (final call in response.calls) {
///       print('Function: ${call.name}');
///       print('Arguments: ${call.arguments}');
///
///       // Execute the function and add result back
///       final result = await executeFunction(call.name, call.arguments);
///       final toolMessage = ChatMessage.tool(result);
///     }
///   }
/// }
/// ```
class LeapFunctionCall {
  /// Creates a new [LeapFunctionCall].
  ///
  /// [name] is the name of the function to call.
  /// [arguments] is a map of argument names to their values.
  const LeapFunctionCall({
    required this.name,
    required this.arguments,
  });

  /// The name of the function to call.
  ///
  /// This should match one of the function names registered with the
  /// conversation via [Conversation.registerFunction].
  final String name;

  /// The arguments for the function call.
  ///
  /// Keys are parameter names, values can be:
  /// - [String] for string arguments
  /// - [num] for numeric arguments
  /// - [bool] for boolean arguments
  /// - [List] for array arguments
  /// - [Map<String, dynamic>] for object arguments
  /// - `null` for null values
  final Map<String, dynamic> arguments;

  /// Gets an argument value by name, with optional type checking.
  ///
  /// Returns `null` if the argument doesn't exist.
  ///
  /// ## Example
  ///
  /// ```dart
  /// final city = call.getArgument<String>('city');
  /// final temperature = call.getArgument<num>('temperature');
  /// ```
  T? getArgument<T>(String name) {
    final value = arguments[name];
    if (value is T) return value;
    return null;
  }

  /// Checks if all required arguments are present.
  ///
  /// [requiredArgs] is a list of argument names that must be present.
  /// Returns `true` if all required arguments exist (even if null).
  bool hasRequiredArguments(List<String> requiredArgs) {
    return requiredArgs.every(arguments.containsKey);
  }

  /// Converts this function call to a JSON-serializable map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'arguments': arguments,
    };
  }

  /// Creates a [LeapFunctionCall] from a JSON map.
  factory LeapFunctionCall.fromJson(Map<String, dynamic> json) {
    return LeapFunctionCall(
      name: json['name'] as String,
      arguments: Map<String, dynamic>.from(json['arguments'] as Map),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! LeapFunctionCall) return false;
    return name == other.name && _mapEquals(arguments, other.arguments);
  }

  @override
  int get hashCode => Object.hash(name, Object.hashAll(arguments.entries));

  @override
  String toString() => 'LeapFunctionCall(name: $name, arguments: $arguments)';

  static bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (a[key] != b[key]) return false;
    }
    return true;
  }
}
