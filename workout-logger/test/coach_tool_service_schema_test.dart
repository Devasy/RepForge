import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/sql_query_service.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_ml_service.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  test(
    'custom exercise tools declare multiple resistance and stretch scores',
    () {
      final storage = MockStorageService();
      final wp = WorkoutProvider(
        storage,
        mlService: MockMLService(),
        programManager: ProgramManager(storage),
      );
      final tools = CoachToolService(
        workoutProvider: wp,
        prManager: PRManager(storage),
      );
      for (final name in ['add_custom_exercise', 'update_exercise']) {
        final declaration = tools
            .buildTools()
            .single
            .functionDeclarations!
            .firstWhere((d) => d.name == name);
        final schema = declaration.parameters!.toJson();
        final properties = schema['properties'] as Map;
        expect(
          properties.keys,
          containsAll([
            'muscle_activations',
            'resistance_intensities',
            'stretch_intensities',
          ]),
        );
        for (final key in ['resistance_intensities', 'stretch_intensities']) {
          final values = properties[key] as Map;
          expect(values['type'], 'ARRAY');
          expect(
            (values['items'] as Map)['required'],
            containsAll(['muscle', 'intensity']),
          );
        }
      }
      wp.dispose();
    },
  );
  test('run_sql_query schema description includes the new health tables', () {
    final storage = MockStorageService();
    final wp = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    final prm = PRManager(storage);
    final tools = CoachToolService(
      workoutProvider: wp,
      prManager: prm,
      sqlQuery: SqlQueryService('unused.db'),
    );

    final decl = tools.buildTools().single.functionDeclarations!.firstWhere(
      (d) => d.name == 'run_sql_query',
    );

    expect(decl.description, contains('health_samples'));
    expect(decl.description, contains('sleep_sessions'));
    expect(decl.description, contains('sleep_stage_intervals'));
    expect(decl.description, contains('exercise_type'));
    expect(decl.description, contains('default_handle'));
    expect(
      decl.description,
      contains('body_weight_at_log, load_mode, load_encoding_version'),
    );
    expect(
      decl.description,
      contains('personal_records(exercise_id, handle, load_encoding_version'),
    );
    expect(decl.description, contains('session_effort'));
    expect(decl.description, contains('program_id'));
    expect(decl.description, contains('program_day_id'));
    expect(decl.description, contains('program_week_number'));
  });
}
