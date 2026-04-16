// Unit Tests for ProgramManager
//
// Tests: CRUD operations, import/export, UUID reassignment, FormatException propagation.

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  group('ProgramManager', () {
    late MockStorageService mockStorage;
    late ProgramManager manager;

    setUp(() async {
      mockStorage = MockStorageService();
      manager = ProgramManager(mockStorage);
    });

    TrainingProgram sampleProgram({
      String id = 'test-id',
      String name = 'Test Program',
      bool isImported = false,
    }) {
      return TrainingProgram(
        id: id,
        name: name,
        description: 'A test program',
        author: 'Tester',
        totalWeeks: 4,
        phases: [
          TrainingPhase(
            id: 'phase-1',
            name: 'Foundation',
            startWeek: 1,
            endWeek: 4,
          ),
        ],
        weeks: [
          ProgramWeek(
            weekNumber: 1,
            days: [
              ProgramDay(
                id: 'day-1',
                name: 'Push',
                exercises: [
                  ProgramExerciseSlot(
                    exerciseId: 'bench_press',
                    sets: 3,
                    minReps: 8,
                    maxReps: 12,
                    restSeconds: 90,
                  ),
                ],
              ),
            ],
          ),
        ],
        isImported: isImported,
      );
    }

    // ==================== CRUD ====================

    group('saveProgram', () {
      test('should save a new program', () async {
        final program = sampleProgram();
        await manager.saveProgram(program);

        expect(manager.programs.length, 1);
        expect(manager.programs.first.name, 'Test Program');
      });

      test('should update an existing program (upsert)', () async {
        final program = sampleProgram();
        await manager.saveProgram(program);

        final updated = program.copyWith(name: 'Updated Name');
        await manager.saveProgram(updated);

        expect(manager.programs.length, 1);
        expect(manager.programs.first.name, 'Updated Name');
      });

      test('should persist to storage', () async {
        final program = sampleProgram();
        await manager.saveProgram(program);

        final storedPrograms = await mockStorage.getAllTrainingPrograms();
        expect(storedPrograms.length, 1);
        expect(storedPrograms.first.id, program.id);
      });
    });

    group('deleteProgram', () {
      test('should remove program from in-memory list', () async {
        final program = sampleProgram();
        await manager.saveProgram(program);

        await manager.deleteProgram(program.id);

        expect(manager.programs, isEmpty);
      });

      test('should remove program from storage', () async {
        final program = sampleProgram();
        await manager.saveProgram(program);

        await manager.deleteProgram(program.id);

        final storedPrograms = await mockStorage.getAllTrainingPrograms();
        expect(storedPrograms, isEmpty);
      });
    });

    group('loadPrograms', () {
      test('should populate from storage', () async {
        // Pre-populate storage
        final program = sampleProgram();
        await mockStorage.saveTrainingProgram(program);

        await manager.loadPrograms();

        expect(manager.programs.length, 1);
        expect(manager.programs.first.name, 'Test Program');
      });
    });

    group('getProgramById', () {
      test('should return program when found', () async {
        final program = sampleProgram(id: 'find-me');
        await manager.saveProgram(program);

        final found = manager.getProgramById('find-me');
        expect(found, isNotNull);
        expect(found!.id, 'find-me');
      });

      test('should return null when not found', () {
        final found = manager.getProgramById('nonexistent');
        expect(found, isNull);
      });
    });

    // ==================== IMPORT / EXPORT ====================

    group('importFromJson', () {
      test('should assign a new UUID on import', () async {
        final original = sampleProgram(id: 'original-id');
        final json = const JsonEncoder.withIndent('  ').convert(
          original.toJson(),
        );

        final imported = await manager.importFromJson(json);

        expect(imported.id, isNot(equals('original-id')));
      });

      test('should mark isImported = true', () async {
        final original = sampleProgram(isImported: false);
        final json = jsonEncode(original.toJson());

        final imported = await manager.importFromJson(json);

        expect(imported.isImported, isTrue);
      });

      test('should set a new createdAt timestamp', () async {
        final original = sampleProgram();
        final originalCreatedAt = original.createdAt;
        final json = jsonEncode(original.toJson());

        // Small delay to ensure different timestamp
        await Future.delayed(const Duration(milliseconds: 10));
        final imported = await manager.importFromJson(json);

        // The imported createdAt should be >= the original
        expect(
          imported.createdAt.millisecondsSinceEpoch,
          greaterThanOrEqualTo(originalCreatedAt.millisecondsSinceEpoch),
        );
      });

      test('should persist the imported program', () async {
        final original = sampleProgram();
        final json = jsonEncode(original.toJson());

        await manager.importFromJson(json);

        expect(manager.programs.length, 1);
        final storedPrograms = await mockStorage.getAllTrainingPrograms();
        expect(storedPrograms.length, 1);
      });

      test('should throw FormatException on malformed JSON', () async {
        expect(
          () => manager.importFromJson('not valid json'),
          throwsA(isA<FormatException>()),
        );
      });

      test('should throw on missing required fields', () async {
        const incompleteJson = '{"id": "x"}';
        expect(
          () => manager.importFromJson(incompleteJson),
          throwsA(isA<Error>()),
        );
      });
    });

    group('exportToJson', () {
      test('should produce valid JSON', () {
        final program = sampleProgram();
        final json = manager.exportToJson(program);

        // Should not throw
        final decoded = jsonDecode(json) as Map<String, dynamic>;
        expect(decoded['name'], 'Test Program');
      });

      test('export → import round-trip preserves data', () async {
        final original = sampleProgram();
        final json = manager.exportToJson(original);

        final imported = await manager.importFromJson(json);

        // Core data should match (id, isImported, createdAt are intentionally different)
        expect(imported.name, original.name);
        expect(imported.description, original.description);
        expect(imported.author, original.author);
        expect(imported.totalWeeks, original.totalWeeks);
        expect(imported.phases.length, original.phases.length);
        expect(imported.weeks.length, original.weeks.length);
        expect(
          imported.weeks.first.days.first.exercises.first.exerciseId,
          original.weeks.first.days.first.exercises.first.exerciseId,
        );
      });
    });

    group('createProgram', () {
      test('should create and save a new program', () async {
        final program = await manager.createProgram(
          name: 'Created Program',
          totalWeeks: 6,
        );

        expect(program.name, 'Created Program');
        expect(program.totalWeeks, 6);
        expect(manager.programs.length, 1);
      });
    });
  });
}
