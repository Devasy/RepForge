// Agent Pending Action
//
// Describes a write the OS AI agent proposed (via an Android AppFunction) that
// must be confirmed by the user before it is committed to local storage.

import 'dart:convert';

/// A proposed, not-yet-committed write originating from the OS agent.
class AgentPendingAction {
  static const String typeCreateExercise = 'createCustomExercise';
  static const String typeCreateRoutine = 'createRoutine';

  final String type;
  final Map<String, dynamic> data;

  const AgentPendingAction({required this.type, required this.data});

  bool get isCreateExercise => type == typeCreateExercise;
  bool get isCreateRoutine => type == typeCreateRoutine;

  /// Parse a JSON payload delivered by the native AppFunction layer.
  ///
  /// Returns null if the payload is missing, malformed, or of an unknown type.
  static AgentPendingAction? tryParse(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);
      final type = map['type'];
      if (type != typeCreateExercise && type != typeCreateRoutine) {
        return null;
      }
      final data = map['data'];
      return AgentPendingAction(
        type: type as String,
        data: data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{},
      );
    } catch (_) {
      return null;
    }
  }
}
