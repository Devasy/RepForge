import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/services/ai/coach_tool_service.dart';
import 'package:repforge/services/ai/sql_query_service.dart';
import 'package:repforge/services/managers/pr_manager.dart';
import 'package:repforge/services/managers/program_manager.dart';
import 'package:repforge/services/workout_provider.dart';

import 'test_utils/mock_ml_service.dart';
import 'test_utils/mock_storage_service.dart';

void main() {
  test('run_sql_query schema description includes the new health tables', () {
    final storage = MockStorageService();
    final wp = WorkoutProvider(
      storage,
      mlService: MockMLService(),
      programManager: ProgramManager(storage),
    );
    final prm = PRManager(storage);
    final tools = CoachToolService(wp, prm, sqlQuery: SqlQueryService('unused.db'));

    final decl = tools
        .buildTools()
        .single
        .functionDeclarations!
        .firstWhere((d) => d.name == 'run_sql_query');

    expect(decl.description, contains('health_samples'));
    expect(decl.description, contains('sleep_sessions'));
    expect(decl.description, contains('sleep_stage_intervals'));
  });
}
