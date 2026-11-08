// Program Manager — SRP-focused manager for Training Programs
//
// Handles: loading, saving, deleting, importing, and exporting
// TrainingProgram entities. Follows the same manager pattern used
// by RoutineManager, TargetManager, etc.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

class ProgramManager extends ChangeNotifier {
  final IStorageService _storage;
  final Uuid _uuid = const Uuid();

  List<TrainingProgram> _programs = [];
  String? _followedProgramId;
  static const _followedKey = 'programs.followedId';

  TrainingProgram? get followedProgram =>
      getProgramById(_followedProgramId ?? '');

  Future<void> followProgram(String? id) async {
    if (id != null && getProgramById(id) == null) {
      throw ArgumentError('Program is no longer available');
    }
    await _storage.saveSetting(_followedKey, id ?? '');
    _followedProgramId = id;
    notifyListeners();
  }

  bool isDayCompleted({
    required TrainingProgram program,
    required ProgramWeek week,
    required ProgramDay day,
    required List<WorkoutSession> sessions,
  }) => sessions.any(
    (s) =>
        s.programId == program.id &&
        s.programWeekNumber == week.weekNumber &&
        s.programDayId == day.id &&
        s.exercises.any((e) => e.sets.isNotEmpty),
  );

  ({int completed, int total}) progressFor({
    required TrainingProgram program,
    required List<WorkoutSession> sessions,
  }) {
    var completed = 0;
    var total = 0;
    for (final week in program.weeks) {
      for (final day in week.days.where((day) => day.exercises.isNotEmpty)) {
        total++;
        if (isDayCompleted(
          program: program,
          week: week,
          day: day,
          sessions: sessions,
        )) {
          completed++;
        }
      }
    }
    return (completed: completed, total: total);
  }

  ({ProgramWeek week, ProgramDay day})? nextWorkout(
    TrainingProgram program,
    List<WorkoutSession> sessions,
  ) {
    final weeks = [...program.weeks]
      ..sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
    for (final week in weeks) {
      for (final day in week.days) {
        if (day.exercises.isNotEmpty &&
            !isDayCompleted(
              program: program,
              week: week,
              day: day,
              sessions: sessions,
            )) {
          return (week: week, day: day);
        }
      }
    }
    return null;
  }

  List<TrainingProgram> get programs => List.unmodifiable(_programs);

  ProgramManager(this._storage);

  // ==================== LOAD ====================

  Future<void> loadPrograms() async {
    _programs = await _storage.getAllTrainingPrograms();
    _followedProgramId = await _storage.getSetting(_followedKey);
    notifyListeners();
  }

  // ==================== CRUD ====================

  Future<void> saveProgram(TrainingProgram program) async {
    await _storage.saveTrainingProgram(program);
    final idx = _programs.indexWhere((p) => p.id == program.id);
    if (idx >= 0) {
      _programs[idx] = program;
    } else {
      _programs.insert(0, program);
    }
    notifyListeners();
  }

  Future<TrainingProgram> createProgram({
    required String name,
    String? description,
    String? author,
    required int totalWeeks,
    List<TrainingPhase>? phases,
    List<ProgramWeek>? weeks,
  }) async {
    final program = TrainingProgram(
      id: _uuid.v4(),
      name: name,
      description: description,
      author: author,
      totalWeeks: totalWeeks,
      phases: phases ?? [],
      weeks: weeks ?? [],
    );
    await saveProgram(program);
    return program;
  }

  Future<void> deleteProgram(String id) async {
    // Clear the persisted choice first so recreating this ID cannot silently follow it.
    if (_followedProgramId == id) await followProgram(null);
    await _storage.deleteTrainingProgram(id);
    _programs.removeWhere((p) => p.id == id);
    notifyListeners();
  }

  // ==================== IMPORT / EXPORT ====================

  /// Import a program from a raw JSON string.
  ///
  /// The JSON must match the [TrainingProgram.toJson] schema.
  /// A new UUID is assigned so imports never conflict with existing IDs.
  /// Throws a [FormatException] if the JSON is malformed or missing required fields.
  Future<TrainingProgram> importFromJson(String jsonString) async {
    final Map<String, dynamic> raw =
        jsonDecode(jsonString) as Map<String, dynamic>;

    // Assign a new local ID and mark as imported
    raw['id'] = _uuid.v4();
    raw['isImported'] = true;
    raw['createdAt'] = DateTime.now().toIso8601String();

    final program = TrainingProgram.fromJson(raw);
    await saveProgram(program);
    return program;
  }

  /// Export a program as a pretty-printed JSON string.
  String exportToJson(TrainingProgram program) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(program.toJson());
  }

  // ==================== HELPERS ====================

  TrainingProgram? getProgramById(String id) {
    try {
      return _programs.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }
}
