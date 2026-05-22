// Tests for AgentMirrorWriter and AgentPendingAction parsing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/models/models.dart';
import 'package:repforge/services/agent_action.dart';
import 'package:repforge/services/agent_data_service.dart';
import 'package:repforge/services/agent_mirror_writer.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_storage_service.dart';

void main() {
  group('AgentMirrorWriter', () {
    late Directory tempDir;
    late WorkoutProvider provider;
    late AgentMirrorWriter writer;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('agent_mirror_test');

      final storage = MockStorageService();
      storage.addMockCustomExercise(
        Exercise(
          id: 'ex_bench',
          name: 'Barbell Bench Press',
          category: 'compound',
          isCustom: true,
          muscleActivations: [
            MuscleActivation(muscleGroupId: 'chest', activationPercentage: 100),
          ],
        ),
      );
      storage.addMockSession(
        WorkoutSession(
          id: 's1',
          date: DateTime.now(),
          duration: 45,
          exercises: [
            ExerciseLog(
              exerciseId: 'ex_bench',
              sets: [WorkoutSet(weight: 60, reps: 10)],
            ),
          ],
        ),
      );

      provider = WorkoutProvider(
        storage,
        programManager: ProgramManager(storage),
      );
      await provider.init();

      writer = AgentMirrorWriter(
        AgentDataService(provider),
        provider,
        directoryResolver: () async => tempDir,
      );
    });

    tearDown(() async {
      writer.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('writeNow writes a decodable snapshot file', () async {
      await writer.writeNow();

      final file = File(
        '${tempDir.path}${Platform.pathSeparator}${AgentMirrorWriter.fileName}',
      );
      expect(file.existsSync(), isTrue);

      final decoded = jsonDecode(await file.readAsString())
          as Map<String, dynamic>;
      expect(decoded['schemaVersion'], 1);
      expect((decoded['sessions'] as List).length, 1);
      expect((decoded['exercises'] as List), isNotEmpty);
    });

    test('start writes an initial snapshot', () async {
      await writer.start();

      final file = await writer.mirrorFile();
      expect(file.existsSync(), isTrue);
    });
  });

  group('AgentPendingAction.tryParse', () {
    test('parses a create-exercise payload', () {
      final action = AgentPendingAction.tryParse(jsonEncode({
        'type': 'createCustomExercise',
        'data': {'name': 'Cable Fly', 'category': 'isolation'},
      }));
      expect(action, isNotNull);
      expect(action!.isCreateExercise, isTrue);
      expect(action.data['name'], 'Cable Fly');
    });

    test('parses a create-routine payload', () {
      final action = AgentPendingAction.tryParse(jsonEncode({
        'type': 'createRoutine',
        'data': {
          'name': 'Push Day',
          'exercises': ['Bench Press', 'Overhead Press'],
        },
      }));
      expect(action, isNotNull);
      expect(action!.isCreateRoutine, isTrue);
      expect((action.data['exercises'] as List).length, 2);
    });

    test('returns null for null, empty, malformed, or unknown payloads', () {
      expect(AgentPendingAction.tryParse(null), isNull);
      expect(AgentPendingAction.tryParse(''), isNull);
      expect(AgentPendingAction.tryParse('not json'), isNull);
      expect(
        AgentPendingAction.tryParse(jsonEncode({'type': 'deleteEverything'})),
        isNull,
      );
    });
  });
}
