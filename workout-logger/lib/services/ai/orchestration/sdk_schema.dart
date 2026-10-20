import 'package:ai_orchestration/ai_orchestration.dart';
import 'package:google_generative_ai/google_generative_ai.dart' as sdk;

JsonMap sdkArgumentSchema(sdk.FunctionDeclaration declaration) => _schema(
  jsonObject(
    declaration.parameters?.toJson() ??
        {'type': 'object', 'properties': <String, Object?>{}},
  ),
);

JsonMap _schema(JsonMap schema) => {
  for (final entry in schema.entries)
    entry.key: switch (entry.key) {
      'type' => (entry.value! as String).toLowerCase(),
      'properties' => jsonObject(
        entry.value,
      ).map((key, value) => MapEntry(key, _schema(jsonObject(value)))),
      'items' => _schema(jsonObject(entry.value)),
      _ => entry.value,
    },
  if (schema['type'].toString().toLowerCase() == 'object')
    'additionalProperties': false,
};
