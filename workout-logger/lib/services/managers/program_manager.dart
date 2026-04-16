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

  List<TrainingProgram> get programs => List.unmodifiable(_programs);

  ProgramManager(this._storage);

  // ==================== LOAD ====================

  Future<void> loadPrograms() async {
    _programs = await _storage.getAllTrainingPrograms();
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
