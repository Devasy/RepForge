import 'dart:convert';
import '../models/models.dart';

/// Validate the complete payload before either backend starts merging records.
/// Legacy backups omit backupFormatVersion and may contain JSON-string rows.
Map<String, dynamic> decodeBackup(String source) {
  final decoded = jsonDecode(source);
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Backup must be an object.');
  }
  final version = decoded['backupFormatVersion'];
  if (version != null && version != 1) {
    throw const FormatException('Unsupported backup format.');
  }
  final validators = <String, Object Function(Map<String, dynamic>)>{
    'sessions': WorkoutSession.fromJson,
    'routines': Routine.fromJson,
    'targets': Target.fromJson,
    'muscleGroups': MuscleGroup.fromJson,
    'customExercises': Exercise.fromJson,
    'exerciseOverrides': Exercise.fromJson,
    'trainingPrograms': TrainingProgram.fromJson,
    'personalRecords': PersonalRecord.fromJson,
    'conversations': Conversation.fromJson,
  };
  if (!validators.keys.any(decoded.containsKey) &&
      !decoded.containsKey('settings')) {
    throw const FormatException('No backup data found.');
  }
  for (final entry in validators.entries) {
    if (!decoded.containsKey(entry.key)) continue;
    final rows = decoded[entry.key];
    if (rows is! List) throw FormatException('${entry.key} must be a list.');
    decoded[entry.key] = [
      for (final row in rows) _validateRow(row, entry.value),
    ];
  }
  if (decoded.containsKey('settings') &&
      decoded['settings'] is! Map<String, dynamic>) {
    throw const FormatException('Settings must be an object.');
  }
  return decoded;
}

Map<String, dynamic> _validateRow(
  Object? row,
  Object Function(Map<String, dynamic>) validate,
) {
  final value = row is String ? jsonDecode(row) : row;
  if (value is! Map<String, dynamic>) {
    throw const FormatException('Invalid backup record.');
  }
  validate(value);
  return value;
}
