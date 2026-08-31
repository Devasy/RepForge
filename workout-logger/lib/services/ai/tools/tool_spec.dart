// tool_spec.dart — SDK-agnostic tool/function declarations.
//
// Replaces direct use of google_generative_ai's FunctionDeclaration, Schema,
// and Tool types. The GeminiProviderAdapter translates these to Gemini's
// wire format; future providers do the same for their SDK.

/// A single tool parameter declaration.
class ToolParam {
  final String type; // 'string', 'integer', 'number', 'boolean', 'array', 'object'
  final String? description;
  final bool nullable;

  /// For arrays: the element type.
  final ToolParam? items;

  /// For objects: the property declarations.
  final Map<String, ToolParam>? properties;

  /// For objects: which properties are required.
  final List<String>? requiredProperties;

  const ToolParam({
    required this.type,
    this.description,
    this.nullable = false,
    this.items,
    this.properties,
    this.requiredProperties,
  });

  /// Convenience constructors matching the google_generative_ai Schema API.
  const ToolParam.string({this.description, this.nullable = false})
      : type = 'string',
        items = null,
        properties = null,
        requiredProperties = null;

  const ToolParam.integer({this.description, this.nullable = false})
      : type = 'integer',
        items = null,
        properties = null,
        requiredProperties = null;

  const ToolParam.number({this.description, this.nullable = false})
      : type = 'number',
        items = null,
        properties = null,
        requiredProperties = null;

  const ToolParam.boolean({this.description, this.nullable = false})
      : type = 'boolean',
        items = null,
        properties = null,
        requiredProperties = null;

  const ToolParam.array({required this.items, this.description, this.nullable = false})
      : type = 'array',
        properties = null,
        requiredProperties = null;

  const ToolParam.object({
    required this.properties,
    this.requiredProperties,
    this.description,
    this.nullable = false,
  })  : type = 'object',
        items = null;
}

/// An SDK-agnostic tool declaration (name + description + parameters schema).
class ToolSpec {
  final String name;
  final String description;
  final Map<String, ToolParam> parameters;
  final List<String> required;

  const ToolSpec({
    required this.name,
    required this.description,
    this.parameters = const {},
    this.required = const [],
  });

  @override
  String toString() => 'ToolSpec($name)';
}
