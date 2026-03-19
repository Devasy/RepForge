// Program Manager (Single Responsibility Principle)
//
// Responsible ONLY for managing training programs and enrollments.
// Handles: import from JSON, CRUD on programs, enrollment lifecycle.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../models/models.dart';
import '../interfaces/storage_service_interface.dart';

class ProgramManager extends ChangeNotifier {
  final IStorageService _storage;
  final Uuid _uuid = const Uuid();

  List<TrainingProgram> _programs = [];
  ProgramEnrollment? _activeEnrollment;

  ProgramManager(this._storage);

  List<TrainingProgram> get programs => List.unmodifiable(_programs);
  ProgramEnrollment? get activeEnrollment => _activeEnrollment;
  int get totalPrograms => _programs.length;

  TrainingProgram? get activeProgram {
    if (_activeEnrollment == null) return null;
    try {
      return _programs.firstWhere((p) => p.id == _activeEnrollment!.programId);
    } catch (_) {
      return null;
    }
  }

  /// Load all programs and active enrollment from storage
  Future<void> loadPrograms() async {
    _programs = await _storage.getAllTrainingPrograms();
    _activeEnrollment = await _storage.getActiveEnrollment();
    notifyListeners();
  }

  /// Get a program by ID
  TrainingProgram? getProgram(String id) {
    try {
      return _programs.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Import a training program from JSON string
  ///
  /// The JSON must conform to the TrainingProgram.toJson() schema.
  /// Returns the imported program, or throws if invalid.
  Future<TrainingProgram> importProgramFromJson(String jsonString) async {
    final Map<String, dynamic> data =
        jsonDecode(jsonString) as Map<String, dynamic>;

    // Assign a fresh ID so imports never collide with existing programs
    data['id'] = _uuid.v4();
    data['isImported'] = true;
    data['createdAt'] = DateTime.now().toIso8601String();

    final program = TrainingProgram.fromJson(data);
    await _storage.saveTrainingProgram(program);
    _programs.insert(0, program);
    notifyListeners();
    return program;
  }

  /// Save a manually created program
  Future<TrainingProgram> createProgram(TrainingProgram program) async {
    final newProgram = TrainingProgram.fromJson({
      ...program.toJson(),
      'id': _uuid.v4(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _storage.saveTrainingProgram(newProgram);
    _programs.insert(0, newProgram);
    notifyListeners();
    return newProgram;
  }

  /// Delete a program (also cancels enrollment if active for that program)
  Future<void> deleteProgram(String id) async {
    await _storage.deleteTrainingProgram(id);
    _programs.removeWhere((p) => p.id == id);
    if (_activeEnrollment?.programId == id) {
      await _storage.deleteEnrollment(_activeEnrollment!.id);
      _activeEnrollment = null;
    }
    notifyListeners();
  }

  /// Start enrollment in a program (deactivates any current enrollment)
  Future<ProgramEnrollment> enrollInProgram(String programId) async {
    // Deactivate existing active enrollment
    if (_activeEnrollment != null && _activeEnrollment!.isActive) {
      final deactivated = _activeEnrollment!.copyWith(isActive: false);
      await _storage.saveEnrollment(deactivated);
    }

    final enrollment = ProgramEnrollment(
      id: _uuid.v4(),
      programId: programId,
      startDate: DateTime.now(),
      currentWeek: 1,
      isActive: true,
    );
    await _storage.saveEnrollment(enrollment);
    _activeEnrollment = enrollment;
    notifyListeners();
    return enrollment;
  }

  /// Mark a workout day as completed for the current week
  Future<void> markDayCompleted(String dayOfWeek) async {
    if (_activeEnrollment == null) return;
    final updated = Map<String, bool>.from(_activeEnrollment!.completedDays);
    updated[_activeEnrollment!.dayKey(_activeEnrollment!.currentWeek, dayOfWeek)] = true;
    _activeEnrollment = _activeEnrollment!.copyWith(completedDays: updated);
    await _storage.saveEnrollment(_activeEnrollment!);
    notifyListeners();
  }

  /// Advance to the next week of the program
  Future<void> advanceWeek() async {
    if (_activeEnrollment == null) return;
    final program = activeProgram;
    if (program == null) return;

    final nextWeek = _activeEnrollment!.currentWeek + 1;
    if (nextWeek > program.durationWeeks) {
      _activeEnrollment = _activeEnrollment!.copyWith(
        isCompleted: true,
        isActive: false,
      );
    } else {
      _activeEnrollment = _activeEnrollment!.copyWith(currentWeek: nextWeek);
    }
    await _storage.saveEnrollment(_activeEnrollment!);
    notifyListeners();
  }

  /// Update the working weight for an exercise in the active enrollment
  Future<void> updateWorkingWeight(String exerciseId, double weightKg) async {
    if (_activeEnrollment == null) return;
    final updated = Map<String, double>.from(_activeEnrollment!.currentWeights);
    updated[exerciseId] = weightKg;
    _activeEnrollment = _activeEnrollment!.copyWith(currentWeights: updated);
    await _storage.saveEnrollment(_activeEnrollment!);
    notifyListeners();
  }

  /// Mark a milestone as completed
  Future<void> completeMilestone(String milestoneId) async {
    if (_activeEnrollment == null) return;
    final updated = Set<String>.from(_activeEnrollment!.completedMilestoneIds)
      ..add(milestoneId);
    _activeEnrollment = _activeEnrollment!.copyWith(
      completedMilestoneIds: updated,
    );
    await _storage.saveEnrollment(_activeEnrollment!);
    notifyListeners();
  }

  /// Leave / cancel the current enrollment
  Future<void> leaveProgram() async {
    if (_activeEnrollment == null) return;
    final deactivated = _activeEnrollment!.copyWith(isActive: false);
    await _storage.saveEnrollment(deactivated);
    _activeEnrollment = null;
    notifyListeners();
  }

  /// Returns the active phase for the current enrollment week
  ProgramPhase? get currentPhase {
    final program = activeProgram;
    if (program == null || _activeEnrollment == null) return null;
    return program.phaseForWeek(_activeEnrollment!.currentWeek);
  }

  /// Returns deload config for a given week if applicable
  DeloadConfig? deloadForWeek(TrainingProgram program, int week) {
    try {
      return program.deloadWeeks.firstWhere((d) => d.weekNumber == week);
    } catch (_) {
      return null;
    }
  }

  /// Export a program back to JSON string
  String exportProgramToJson(String programId) {
    final program = getProgram(programId);
    if (program == null) throw Exception('Program not found: $programId');
    return const JsonEncoder.withIndent('  ').convert(program.toJson());
  }
}
