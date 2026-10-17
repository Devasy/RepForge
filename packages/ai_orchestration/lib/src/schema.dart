import 'json.dart';

/// A deliberately bounded schema vocabulary, validated before tool dispatch.
class ValueSchema {
  final JsonMap definition;
  ValueSchema(JsonMap definition) : definition = jsonObject(definition) {
    _checkDefinition(this.definition);
  }

  factory ValueSchema.string({List<String>? values}) =>
      ValueSchema({'type': 'string', 'enum': ?values});
  factory ValueSchema.boolean() => ValueSchema({'type': 'boolean'});
  factory ValueSchema.integer({int? minimum, int? maximum}) => ValueSchema({
    'type': 'integer',
    'minimum': ?minimum,
    'maximum': ?maximum,
  });
  factory ValueSchema.object({
    Map<String, ValueSchema> properties = const {},
    List<String> required = const [],
  }) => ValueSchema({
    'type': 'object',
    'properties': properties.map(
      (key, value) => MapEntry(key, value.definition),
    ),
    'required': required,
    'additionalProperties': false,
  });

  static void _checkDefinition(JsonMap schema) {
    const supported = {
      'type',
      'enum',
      'properties',
      'required',
      'additionalProperties',
      'items',
      'minimum',
      'maximum',
      'minItems',
      'maxItems',
    };
    if (schema.keys.any((key) => !supported.contains(key)) ||
        !{
          'object',
          'array',
          'string',
          'integer',
          'number',
          'boolean',
          'null',
        }.contains(schema['type'])) {
      throw ArgumentError('Unsupported schema keyword or type.');
    }
    final properties = schema['properties'];
    if (properties != null) {
      for (final value in jsonObject(properties).values) {
        _checkDefinition(jsonObject(value));
      }
    }
    if (schema['items'] != null) _checkDefinition(jsonObject(schema['items']));
    if (schema['type'] == 'array' && schema['items'] == null) {
      throw ArgumentError('Array schemas require items.');
    }
    final required = schema['required'];
    if (required != null &&
        (required is! List<Object?> ||
            required.any(
              (key) =>
                  key is! String ||
                  !jsonObject(properties ?? {}).containsKey(key),
            ))) {
      throw ArgumentError('Required fields must be declared properties.');
    }
    if (schema['additionalProperties'] != null &&
        schema['additionalProperties'] is! bool) {
      throw ArgumentError('additionalProperties must be boolean.');
    }
    for (final key in ['minimum', 'maximum', 'minItems', 'maxItems']) {
      if (schema[key] != null && schema[key] is! num) {
        throw ArgumentError('$key must be numeric.');
      }
    }
    if (schema['enum'] != null && schema['enum'] is! List<Object?>) {
      throw ArgumentError('enum must be a list.');
    }
  }

  void validate(Object? value) {
    freezeJson(value);
    _validate(definition, value, r'$');
  }

  static Never _invalid(String path, String reason) =>
      throw OrchestrationException('validation', '$path: $reason');

  static void _validate(JsonMap schema, Object? value, String path) {
    final valid = switch (schema['type']) {
      'object' => value is JsonMap,
      'array' => value is List<Object?>,
      'string' => value is String,
      'integer' => value is int,
      'number' => value is num && value.isFinite,
      'boolean' => value is bool,
      'null' => value == null,
      _ => false,
    };
    if (!valid) _invalid(path, 'Expected ${schema['type']}.');
    final allowed = schema['enum'] as List<Object?>?;
    if (allowed != null &&
        !allowed.any((item) => canonicalJson(item) == canonicalJson(value))) {
      _invalid(path, 'Value is not in enum.');
    }
    if (value is num) {
      if (schema['minimum'] case final num min when value < min) {
        _invalid(path, 'Below minimum.');
      }
      if (schema['maximum'] case final num max when value > max) {
        _invalid(path, 'Above maximum.');
      }
    }
    if (value is List<Object?>) {
      if (schema['minItems'] case final num min when value.length < min) {
        _invalid(path, 'Too few items.');
      }
      if (schema['maxItems'] case final num max when value.length > max) {
        _invalid(path, 'Too many items.');
      }
      for (var i = 0; i < value.length; i++) {
        _validate(jsonObject(schema['items']), value[i], '$path[$i]');
      }
    }
    if (value is JsonMap) {
      final properties = jsonObject(schema['properties'] ?? {});
      for (final key in (schema['required'] as List<Object?>? ?? const [])) {
        if (!value.containsKey(key)) _invalid(path, 'Missing $key.');
      }
      for (final entry in value.entries) {
        final child = properties[entry.key];
        if (child != null) {
          _validate(jsonObject(child), entry.value, '$path.${entry.key}');
        } else if (schema['additionalProperties'] == false) {
          _invalid(path, 'Unexpected ${entry.key}.');
        }
      }
    }
  }
}
