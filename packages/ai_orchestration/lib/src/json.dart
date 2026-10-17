import 'dart:convert';
import 'dart:math';

typedef JsonMap = Map<String, Object?>;

Object? freezeJson(Object? value) => switch (value) {
  null || bool() || String() => value,
  num() when value.isFinite => value,
  List<Object?>() => List<Object?>.unmodifiable(value.map(freezeJson)),
  Map<String, Object?>() => Map<String, Object?>.unmodifiable(
    value.map((key, value) => MapEntry(key, freezeJson(value))),
  ),
  _ => throw ArgumentError('Expected finite, JSON-serializable data.'),
};

JsonMap jsonObject(Object? value) {
  if (value is! Map<String, Object?>) {
    throw const FormatException('Expected a JSON object.');
  }
  return freezeJson(value)! as JsonMap;
}

String canonicalJson(Object? value) {
  final frozen = freezeJson(value);
  Object? sort(Object? item) => switch (item) {
    Map<String, Object?>() => {
      for (final key in item.keys.toList()..sort()) key: sort(item[key]),
    },
    List<Object?>() => item.map(sort).toList(),
    _ => item,
  };
  return jsonEncode(sort(frozen));
}

String newIdentifier() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

class OrchestrationException implements Exception {
  final String code;
  final String message;
  const OrchestrationException(this.code, this.message);
  @override
  String toString() => '$code: $message';
}
